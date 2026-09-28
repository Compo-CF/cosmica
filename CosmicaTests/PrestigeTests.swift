import XCTest
@testable import Cosmica

final class PrestigeTests: XCTestCase {

    func test_belowThreshold_yieldsZeroShards() {
        XCTAssertEqual(PrestigeCalculator.shardsEarned(lifetimeStardust: 0), 0)
        XCTAssertEqual(PrestigeCalculator.shardsEarned(lifetimeStardust: 1e11), 0)
        XCTAssertEqual(PrestigeCalculator.shardsEarned(lifetimeStardust: PrestigeCalculator.threshold - 1), 0)
    }

    func test_atThreshold_yields150Shards() {
        XCTAssertEqual(PrestigeCalculator.shardsEarned(lifetimeStardust: PrestigeCalculator.threshold), 150)
    }

    func test_at4xThreshold_yields300Shards() {
        // 150 * sqrt(4) = 300
        XCTAssertEqual(PrestigeCalculator.shardsEarned(lifetimeStardust: 4 * PrestigeCalculator.threshold), 300)
    }

    func test_at100xThreshold_yields1500Shards() {
        // 150 * sqrt(100) = 1500
        XCTAssertEqual(PrestigeCalculator.shardsEarned(lifetimeStardust: 100 * PrestigeCalculator.threshold), 1500)
    }

    func test_lifetimeRequired_inverts_shardsEarned() {
        for target in [10, 50, 150, 300, 1500, 10_000] {
            let req = PrestigeCalculator.lifetimeRequired(forShards: target)
            // floor 0: this checks the curve itself, not the unlock gate.
            let actual = PrestigeCalculator.shardsEarned(lifetimeStardust: req, floor: 0)
            XCTAssertTrue([target - 1, target].contains(actual),
                          "Expected \(target - 1) or \(target), got \(actual) for required=\(req)")
        }
    }

    func test_progress_isMonotonic() {
        // Between shard N and N+1, progress should grow monotonically with lifetime.
        let base = PrestigeCalculator.lifetimeRequired(forShards: 200)
        let next = PrestigeCalculator.lifetimeRequired(forShards: 201)
        let mid = (base + next) / 2
        let p0 = PrestigeCalculator.progressToNextShard(lifetimeStardust: base)
        let pMid = PrestigeCalculator.progressToNextShard(lifetimeStardust: mid)
        let p1 = PrestigeCalculator.progressToNextShard(lifetimeStardust: next - 1)
        XCTAssertLessThanOrEqual(p0, pMid)
        XCTAssertLessThanOrEqual(pMid, p1)
        XCTAssertGreaterThanOrEqual(p0, 0)
        XCTAssertLessThanOrEqual(p1, 1)
    }

    /// Review 2026-09-26: at 5B lifetime the Big Bang tab said "next shard 44.44M"
    /// (threshold / 150²) while the real unlock is 1T.
    func test_beforeUnlock_nextThresholdIsTheUnlockFloor() {
        XCTAssertEqual(PrestigeCalculator.nextShardThreshold(lifetimeStardust: 5e9), PrestigeCalculator.threshold)
        XCTAssertEqual(PrestigeCalculator.nextShardThreshold(lifetimeStardust: 0), PrestigeCalculator.threshold)
        XCTAssertEqual(PrestigeCalculator.progressToNextShard(lifetimeStardust: 5e9), 5e9 / PrestigeCalculator.threshold, accuracy: 1e-12)
        XCTAssertEqual(PrestigeCalculator.progressToNextShard(lifetimeStardust: 0), 0)
    }

    func test_afterUnlock_nextThresholdIsAboveCurrent() {
        let lifetime = PrestigeCalculator.threshold
        XCTAssertGreaterThan(PrestigeCalculator.nextShardThreshold(lifetimeStardust: lifetime), lifetime)
    }

    // MARK: - v3.0.4 first-cosmos ramp

    func test_unlockFloor_rampsInFirstCosmosOnly() {
        XCTAssertEqual(PrestigeCalculator.unlockFloor(prestigeCount: 0, cosmosCount: 0), 1e10)
        XCTAssertEqual(PrestigeCalculator.unlockFloor(prestigeCount: 1, cosmosCount: 0), 1e11)
        XCTAssertEqual(PrestigeCalculator.unlockFloor(prestigeCount: 2, cosmosCount: 0), PrestigeCalculator.threshold)
        XCTAssertEqual(PrestigeCalculator.unlockFloor(prestigeCount: 40, cosmosCount: 0), PrestigeCalculator.threshold)
        // prestigeCount resets on True Cosmos; the ramp must not come back.
        XCTAssertEqual(PrestigeCalculator.unlockFloor(prestigeCount: 0, cosmosCount: 1), PrestigeCalculator.threshold)
    }

    func test_earlyBigBang_paysFromTheSameCurve() {
        XCTAssertEqual(PrestigeCalculator.shardsEarned(lifetimeStardust: 1e10, floor: 1e10), 15)
        XCTAssertEqual(PrestigeCalculator.shardsEarned(lifetimeStardust: 1e11, floor: 1e11), 47)
        XCTAssertEqual(PrestigeCalculator.shardsEarned(lifetimeStardust: 5e9, floor: 1e10), 0)
        // Waiting past the floor still pays more.
        XCTAssertGreaterThan(PrestigeCalculator.shardsEarned(lifetimeStardust: 4e10, floor: 1e10), 15)
    }

    func test_earlyFloor_progressAndNextTarget() {
        XCTAssertEqual(PrestigeCalculator.nextShardThreshold(lifetimeStardust: 5e9, floor: 1e10), 1e10)
        XCTAssertEqual(PrestigeCalculator.progressToNextShard(lifetimeStardust: 5e9, floor: 1e10), 0.5, accuracy: 1e-12)
        XCTAssertGreaterThan(PrestigeCalculator.nextShardThreshold(lifetimeStardust: 1e10, floor: 1e10), 1e10)
    }

    // MARK: - v3.0.4 Autonomous Reactor retired

    func test_firstClusterAutoBuy_needsNoNode() {
        for i in 0...3 {
            XCTAssertTrue(CosmicTree.isGeneratorAutoBuyUnlocked(index: i, levels: [:]))
        }
        XCTAssertFalse(CosmicTree.isGeneratorAutoBuyUnlocked(index: 4, levels: [:]))
        XCTAssertFalse(CosmicTree.isGeneratorAutoBuyUnlocked(index: 8, levels: [:]))
        XCTAssertNil(CosmicTree.skill(CosmicTree.reactorSkillId))
    }

    func test_savedReactor_isRefundedOnce() throws {
        var state = GameState()
        state.cosmicShards = 10
        state.lifetimeCosmicShards = 200
        state.cosmicSkillLevels = [CosmicTree.reactorSkillId: 1, "focus": 2]
        let data = try JSONEncoder().encode(state)

        let loaded = try JSONDecoder().decode(GameState.self, from: data)
        XCTAssertEqual(loaded.cosmicShards, 35)
        XCTAssertEqual(loaded.lifetimeCosmicShards, 200)   // a refund isn't progress
        XCTAssertNil(loaded.cosmicSkillLevels[CosmicTree.reactorSkillId])
        XCTAssertEqual(loaded.cosmicSkillLevels["focus"], 2)

        // Re-saving and loading again must not refund a second time.
        let again = try JSONDecoder().decode(GameState.self, from: JSONEncoder().encode(loaded))
        XCTAssertEqual(again.cosmicShards, 35)
    }
}
