import XCTest
@testable import Cosmica

final class OfflineAccrualTests: XCTestCase {

    func test_zeroElapsed_yieldsZeroEarnings() {
        let now = Date()
        let r = OfflineAccrual.compute(now: now, lastSeen: now, ratePerSecond: 100)
        XCTAssertEqual(r.stardustEarned, 0)
        XCTAssertEqual(r.secondsElapsed, 0)
        XCTAssertFalse(r.wasCapped)
    }

    func test_underCap_uncapped_50PercentRate() {
        let now = Date()
        let lastSeen = now.addingTimeInterval(-3600) // 1h
        let r = OfflineAccrual.compute(now: now, lastSeen: lastSeen, ratePerSecond: 10)
        // 10/s * 3600s * 0.5 = 18,000
        XCTAssertEqual(r.stardustEarned, 18_000, accuracy: 1e-6)
        XCTAssertFalse(r.wasCapped)
    }

    func test_overCap_baseCap_caps8h() {
        let now = Date()
        let lastSeen = now.addingTimeInterval(-12 * 3600) // 12h away
        let r = OfflineAccrual.compute(now: now, lastSeen: lastSeen, ratePerSecond: 10)
        // 8h * 3600s * 10/s * 0.5
        XCTAssertEqual(r.stardustEarned, 8.0 * 3600 * 10 * 0.5, accuracy: 1e-6)
        XCTAssertTrue(r.wasCapped)
        XCTAssertEqual(r.capUsed, 8 * 3600)
    }

    func test_overCap_extended_caps24h() {
        let now = Date()
        let lastSeen = now.addingTimeInterval(-48 * 3600)
        let r = OfflineAccrual.compute(now: now, lastSeen: lastSeen, ratePerSecond: 10, extended: true)
        XCTAssertEqual(r.stardustEarned, 24.0 * 3600 * 10 * 0.5, accuracy: 1e-6)
        XCTAssertTrue(r.wasCapped)
        XCTAssertEqual(r.capUsed, 24 * 3600)
    }

    func test_negativeElapsed_clampedToZero() {
        // Clock skew — lastSeen in the future
        let now = Date()
        let lastSeen = now.addingTimeInterval(3600)
        let r = OfflineAccrual.compute(now: now, lastSeen: lastSeen, ratePerSecond: 10)
        XCTAssertEqual(r.stardustEarned, 0)
    }

    func test_negativeRate_clampedToZero() {
        let now = Date()
        let lastSeen = now.addingTimeInterval(-3600)
        let r = OfflineAccrual.compute(now: now, lastSeen: lastSeen, ratePerSecond: -10)
        XCTAssertEqual(r.stardustEarned, 0)
    }
}
