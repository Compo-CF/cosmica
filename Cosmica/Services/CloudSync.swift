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

    func push(state: GameState) async throws {
        let data = try JSONEncoder().encode(state)
        let record: CKRecord
        do {
            record = try await privateDB.record(for: recordId)
        } catch let error as CKError where error.code == .unknownItem {
            record = CKRecord(recordType: recordType, recordID: recordId)
        }
        record["state"] = data as CKRecordValue
        record["lifetimeStardust"] = state.lifetimeStardust as CKRecordValue
        record["updatedAt"] = Date() as CKRecordValue
        _ = try await privateDB.save(record)
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

    /// Higher lifetimeStardust wins. Simple and cheating-resistant enough for non-competitive sync.
    func reconcile(local: GameState, remote: GameState) -> GameState {
        remote.lifetimeStardust > local.lifetimeStardust ? remote : local
    }
}
