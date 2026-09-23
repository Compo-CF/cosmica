import Foundation
import CloudKit

/// Cross-device save sync via CloudKit private DB.
/// One record per user (`recordName == "primary"`), payload is the JSON-encoded GameState
/// plus a denormalized `lifetimeStardust` for cheap conflict resolution.
actor CloudSync {
    private let container: CKContainer
    private let recordType = "CosmicaState"
    private let recordId = CKRecord.ID(recordName: "primary")

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
    func push(state: GameState) async throws -> PushResult {
        let record: CKRecord
        do {
            record = try await privateDB.record(for: recordId)
            if let data = record["state"] as? Data,
               let remote = try? JSONDecoder().decode(GameState.self, from: data),
               remote.isAhead(of: state) {
                return .remoteAhead(remote)
            }
        } catch let error as CKError where error.code == .unknownItem {
            record = CKRecord(recordType: recordType, recordID: recordId)
        }
        let data = try JSONEncoder().encode(state)
        record["state"] = data as CKRecordValue
        record["lifetimeStardust"] = state.lifetimeStardust as CKRecordValue
        record["updatedAt"] = Date() as CKRecordValue
        _ = try await privateDB.save(record)
        return .saved
    }

    /// True when the device is signed into iCloud and CloudKit is usable. On a
    /// freshly set-up phone this is often false for the first few seconds/minutes.
    func accountAvailable() async -> Bool {
        (try? await container.accountStatus()) == .available
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
