import Foundation
import CloudKit

/// Cross-device save sync via CloudKit private DB.
/// One record per user (`recordName == "primary"`), payload is the JSON-encoded GameState
/// plus a denormalized `lifetimeStardust` for cheap conflict resolution.
actor CloudSync {
    /// Shared instance so Settings (reset / restore) and CosmicaApp (launch /
    /// background sync) talk to the same actor.
    static let shared = CloudSync()

    private let container: CKContainer
    private let recordType = "CosmicaState"
    private let recordId = CKRecord.ID(recordName: "primary")
    /// v3.0.2 — one-level undo. Same record type and fields as "primary", so no
    /// CloudKit schema change / Production deploy is needed.
    private let previousId = CKRecord.ID(recordName: "previous")
    /// Normal pushes refresh the backup at most once a day, so it stays a
    /// meaningfully older checkpoint instead of trailing the live save by minutes.
    private let checkpointInterval: TimeInterval = 24 * 3600

    /// A save plus when it was written — for the Settings restore confirmation.
    struct Snapshot {
        let state: GameState
        let savedAt: Date?
    }

    init(container: CKContainer = .default()) {
        self.container = container
    }

    private var privateDB: CKDatabase { container.privateCloudDatabase }

    /// Outcome of a push. `.remoteAhead` means iCloud holds a save with MORE
    /// progress than this device — we did NOT overwrite it, and the caller should
    /// adopt the returned state instead.
    enum PushResult {
        case saved
        case remoteAhead(GameState)
    }

    /// v3.0.2 — never blindly overwrite. Before v3.0.2 this saved unconditionally,
    /// so a fresh install on a new phone uploaded its empty save the first time it
    /// was backgrounded and destroyed the player's real cloud copy.
    ///
    /// `force: true` skips the "is the cloud ahead?" check — used only for
    /// deliberate player actions (Reset Game, Restore previous save, Developer
    /// Restore). Every forced push checkpoints the save it replaces first, so
    /// those actions are always undoable via "Restore previous save".
    func push(state: GameState, force: Bool = false) async throws -> PushResult {
        let record: CKRecord
        do {
            record = try await privateDB.record(for: recordId)
            if let data = record["state"] as? Data {
                if !force,
                   let remote = try? JSONDecoder().decode(GameState.self, from: data),
                   remote.isAhead(of: state) {
                    return .remoteAhead(remote)
                }
                await checkpoint(record, always: force)
            }
        } catch let error as CKError where error.code == .unknownItem {
            record = CKRecord(recordType: recordType, recordID: recordId)
        }
        let data = try JSONEncoder().encode(state)
        record["state"] = data as CKRecordValue
        record["lifetimeStardust"] = state.lifetimeStardust as CKRecordValue
        record["updatedAt"] = Date() as CKRecordValue
        do {
            _ = try await privateDB.save(record)
        } catch let error as CKError where error.code == .serverRecordChanged {
            // Another device (or an overlapping push) wrote between our fetch and
            // save. Re-check against the server's copy, then write onto it once.
            guard let server = error.serverRecord else { throw error }
            if !force,
               let serverData = server["state"] as? Data,
               let serverState = try? JSONDecoder().decode(GameState.self, from: serverData),
               serverState.isAhead(of: state) {
                return .remoteAhead(serverState)
            }
            server["state"] = data as CKRecordValue
            server["lifetimeStardust"] = state.lifetimeStardust as CKRecordValue
            server["updatedAt"] = Date() as CKRecordValue
            _ = try await privateDB.save(server)
        }
        return .saved
    }

    /// Human-readable iCloud account state, for diagnostics in the UI.
    func accountStatusText() async -> String {
        do {
            switch try await container.accountStatus() {
            case .available:               return "available"
            case .noAccount:               return "not signed in to iCloud"
            case .restricted:              return "restricted (parental controls / MDM)"
            case .couldNotDetermine:       return "could not determine"
            case .temporarilyUnavailable:  return "temporarily unavailable"
            @unknown default:              return "unknown"
            }
        } catch {
            return "error: \(error.localizedDescription)"
        }
    }

    /// v3.0.2 — surface the real reason a CloudKit call failed instead of a
    /// generic message. Names the common CKError codes a player can act on.
    static func describe(_ error: Error) -> String {
        guard let ck = error as? CKError else { return error.localizedDescription }
        let name: String
        switch ck.code {
        case .quotaExceeded:            name = "iCloud storage is full"
        case .notAuthenticated:         name = "not signed in to iCloud (or iCloud is off for Cosmica)"
        case .networkUnavailable, .networkFailure: name = "no network connection"
        case .serviceUnavailable, .zoneBusy, .requestRateLimited: name = "iCloud is busy, try again shortly"
        case .accountTemporarilyUnavailable: name = "iCloud account temporarily unavailable"
        case .permissionFailure:        name = "permission failure"
        case .serverRecordChanged:      name = "save conflict"
        case .invalidArguments:         name = "invalid arguments (possible schema mismatch)"
        case .limitExceeded:            name = "save too large"
        case .badContainer, .missingEntitlement: name = "iCloud container / entitlement problem"
        default:                        name = "CloudKit error"
        }
        return "\(name) [code \(ck.code.rawValue)] \(ck.localizedDescription)"
    }

    /// True when the device is signed into iCloud and CloudKit is usable. On a
    /// freshly set-up phone this is often false for the first few seconds/minutes.
    func accountAvailable() async -> Bool {
        (try? await container.accountStatus()) == .available
    }

    /// Copy the save that's about to be replaced into the "previous" record.
    /// Forced pushes always checkpoint; normal pushes only when the existing
    /// backup is more than a day old. Best-effort — a failed backup never blocks
    /// the real save.
    private func checkpoint(_ primary: CKRecord, always: Bool) async {
        guard let data = primary["state"] as? Data else { return }
        let backup: CKRecord
        if let existing = try? await privateDB.record(for: previousId) {
            if !always,
               let savedAt = existing["updatedAt"] as? Date,
               Date().timeIntervalSince(savedAt) < checkpointInterval {
                return
            }
            backup = existing
        } else {
            backup = CKRecord(recordType: recordType, recordID: previousId)
        }
        backup["state"] = data as CKRecordValue
        backup["lifetimeStardust"] = primary["lifetimeStardust"]
        backup["updatedAt"] = (primary["updatedAt"] as? Date ?? Date()) as CKRecordValue
        _ = try? await privateDB.save(backup)
    }

    /// The one-level backup, or nil if this iCloud account doesn't have one yet.
    func pullPrevious() async throws -> Snapshot? {
        do {
            let rec = try await privateDB.record(for: previousId)
            guard let data = rec["state"] as? Data else { return nil }
            let state = try JSONDecoder().decode(GameState.self, from: data)
            return Snapshot(state: state, savedAt: rec["updatedAt"] as? Date)
        } catch let error as CKError where error.code == .unknownItem {
            return nil
        }
    }

    func pull() async throws -> GameState? {
        do {
            let rec = try await privateDB.record(for: recordId)
            guard let data = rec["state"] as? Data else { return nil }
            return try JSONDecoder().decode(GameState.self, from: data)
        } catch let error as CKError where error.code == .unknownItem {
            return nil
        }
    }

    /// The save with more lasting progress wins — see `GameState.progressRank`.
    /// (Was "higher lifetimeStardust wins", which broke because that value resets
    /// on every Big Bang and True Cosmos.)
    func reconcile(local: GameState, remote: GameState) -> GameState {
        remote.isAhead(of: local) ? remote : local
    }
}
