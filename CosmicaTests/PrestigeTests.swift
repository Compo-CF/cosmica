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
            let actual = PrestigeCalculator.shardsEarned(lifetimeStardust: req)
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
}
