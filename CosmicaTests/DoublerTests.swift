import XCTest
@testable import Cosmica

/// v3.3 — Stardust Doubler: permanent ×2 on all Stardust earnings.
@MainActor
final class DoublerTests: XCTestCase {
    func test_doubler_doublesEarningsAndTaps() {
        var s = GameState()
        s.generators[0].count = 25
        s.cosmicShards = 1e6            // big enough that a tap isn't stuck at its 1 ✦ floor
        let base = s.stardustPerSecond
        let baseTap = s.tapValue
        XCTAssertGreaterThan(baseTap, 1)
        XCTAssertGreaterThan(base, 0)
        s.doublerOwned = true
        XCTAssertEqual(s.stardustPerSecond, base * 2, accuracy: base * 1e-9)
        XCTAssertEqual(s.tapValue, baseTap * 2, accuracy: baseTap * 1e-9)
    }

    func test_doubler_stacksWithTheTimedBoost() {
        var s = GameState()
        s.generators[0].count = 25
        let base = s.stardustPerSecond
        s.doublerOwned = true
        s.adBoostExpiresAt = Date().addingTimeInterval(3600)
        XCTAssertEqual(s.stardustPerSecond, base * 4, accuracy: base * 1e-9)
    }

    func test_doubler_survivesBigBangAndOldSavesDefaultToOff() throws {
        var s = GameState()
        s.lifetimeStardust = 1e12
        s.doublerOwned = true
        let e = GameEngine(state: s, persistence: Persistence.inMemory())
        e.bigBang()
        XCTAssertTrue(e.state.doublerOwned)

        var json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(GameState())) as! [String: Any]
        json.removeValue(forKey: "doublerOwned")
        let old = try JSONDecoder().decode(GameState.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertFalse(old.doublerOwned)
    }
}
