import XCTest
@testable import Cosmica

/// v4.0.4 — Winter Solstice Trail (time-limited event, 13 Dec 2026 – 10 Jan 2027).
@MainActor
final class V404Tests: XCTestCase {
    private func engine() -> GameEngine {
        GameEngine(state: GameState(), persistence: Persistence.inMemory())
    }
    private let before = SolsticeTrail.start.addingTimeInterval(-3600)
    private let during = SolsticeTrail.start.addingTimeInterval(86_400)
    private let after = SolsticeTrail.end.addingTimeInterval(60)

    func test_window_matchesTheInAppEvent() {
        let utc = TimeZone(identifier: "UTC")!
        var cal = Calendar(identifier: .gregorian); cal.timeZone = utc
        let s = cal.dateComponents([.year, .month, .day, .hour], from: SolsticeTrail.start)
        let e = cal.dateComponents([.year, .month, .day, .hour], from: SolsticeTrail.end)
        XCTAssertEqual([s.year, s.month, s.day, s.hour], [2026, 12, 13, 16])
        XCTAssertEqual([e.year, e.month, e.day, e.hour], [2027, 1, 10, 16])
        XCTAssertLessThanOrEqual(SolsticeTrail.end.timeIntervalSince(SolsticeTrail.start), 31 * 86_400)
    }

    func test_notStarted_beforeTheWindow() {
        let e = engine()
        e.refreshSolstice(now: before)
        XCTAssertFalse(e.solsticeStarted)
        XCTAssertTrue(SolsticeTrail.isUpcoming(before))
    }

    func test_goalsSet_onceInsideTheWindow_sizedToThePlayer() {
        let e = engine()
        e.state.totalTaps = 400
        e.refreshSolstice(now: during)
        XCTAssertTrue(e.solsticeStarted)
        XCTAssertEqual(SolsticeTrail.goalAmount(.taps, e.state), Big(SolsticeTrail.taps))
        XCTAssertEqual(SolsticeTrail.goalAmount(.bigBangs, e.state), Big(1), "a new player's first Big Bang")
        XCTAssertEqual(SolsticeTrail.target(.bestRun, e.state), Big(1e9))
        // A second refresh doesn't move the goals.
        e.state.totalTaps = 10_000
        e.refreshSolstice(now: during)
        XCTAssertEqual(SolsticeTrail.baseline(.taps, e.state), Big(400))
    }

    func test_veteranGoals_scaleUp() {
        let e = engine()
        e.state.totalBigBangs = 300
        e.state.autoBigBangEnabled = true
        e.state.bestRunStardust = Big.fromLog10(500)
        e.refreshSolstice(now: during)
        XCTAssertEqual(SolsticeTrail.goalAmount(.bigBangs, e.state), Big(SolsticeTrail.bigBangsAuto))
        XCTAssertEqual(SolsticeTrail.target(.bestRun, e.state).log10Value, 502, accuracy: 0.01)
    }

    func test_tapGoal_latches_claimPaysShards_once() {
        let e = engine()
        e.refreshSolstice(now: during)
        e.state.totalTaps += 2_500
        e.checkSolstice(now: during)
        XCTAssertTrue(SolsticeTrail.isMet(.taps, e.state))
        let before = e.state.cosmicShards
        XCTAssertGreaterThan(e.claimSolstice(.taps), .zero)
        XCTAssertGreaterThan(e.state.cosmicShards, before)
        XCTAssertEqual(e.claimSolstice(.taps), .zero, "can't claim twice")
    }

    func test_allFive_payStarAndFrostOrb() {
        let e = engine()
        e.refreshSolstice(now: during)
        let stars = e.state.challengeStars
        for step in SolsticeStep.allCases { e.state.solsticeMet.append(step.rawValue) }
        for step in SolsticeStep.allCases { e.claimSolstice(step) }
        XCTAssertTrue(e.state.solsticeOrbEarned)
        XCTAssertEqual(e.state.challengeStars, stars + 1)
        XCTAssertTrue(OrbSkin.frost.isUnlocked(state: e.state, supporter: false))
    }

    func test_noProgress_afterTheWindowCloses() {
        let e = engine()
        e.refreshSolstice(now: during)
        e.state.totalTaps += 99_999
        e.checkSolstice(now: after)
        XCTAssertFalse(SolsticeTrail.isMet(.taps, e.state))
    }

    func test_metButUnclaimed_isPaidWhenTheEventEnds() {
        let e = engine()
        e.refreshSolstice(now: during)
        e.state.totalDailyClaims += 5
        e.checkSolstice(now: during)
        e.refreshSolstice(now: after)
        XCTAssertTrue(SolsticeTrail.isClaimed(.dailies, e.state))
        XCTAssertFalse(e.state.solsticeOrbEarned)
    }

    func test_saveRoundTrip_keepsTrail() throws {
        let e = engine()
        e.refreshSolstice(now: during)
        e.state.solsticeMet = ["taps"]
        e.state.solsticeOrbEarned = true
        let data = try JSONEncoder().encode(e.state)
        let back = try JSONDecoder().decode(GameState.self, from: data)
        XCTAssertEqual(back.solsticeMet, ["taps"])
        XCTAssertTrue(back.solsticeOrbEarned)
        XCTAssertEqual(back.solsticeTargets.count, SolsticeStep.allCases.count)
    }

    func test_oldSave_decodesWithEmptyTrail() throws {
        let data = try JSONEncoder().encode(GameState())
        var obj = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        for k in ["solsticeBaselines", "solsticeTargets", "solsticeMet", "solsticeClaimed", "solsticeOrbEarned"] {
            obj.removeValue(forKey: k)
        }
        let old = try JSONSerialization.data(withJSONObject: obj)
        let s = try JSONDecoder().decode(GameState.self, from: old)
        XCTAssertTrue(s.solsticeTargets.isEmpty)
        XCTAssertFalse(s.solsticeOrbEarned)
    }
}
