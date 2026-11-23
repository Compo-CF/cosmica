import XCTest
@testable import Cosmica

/// v4.0.4 — Winter Solstice Trail (time-limited event, 13 Dec 2026 – 10 Jan 2027).
/// v4.0.5 moved it onto the Seasonal Trails API; the behaviour is unchanged.
@MainActor
final class V404Tests: XCTestCase {
    private func engine() -> GameEngine {
        GameEngine(state: GameState(), persistence: Persistence.inMemory())
    }
    private let ev = SeasonalTrails.solstice
    private var before: Date { ev.start.addingTimeInterval(-3600) }
    private var during: Date { ev.start.addingTimeInterval(86_400) }
    private var after: Date { ev.end.addingTimeInterval(60) }

    func test_window_matchesTheInAppEvent() {
        var cal = Calendar(identifier: .gregorian); cal.timeZone = TimeZone(identifier: "UTC")!
        let s = cal.dateComponents([.year, .month, .day, .hour], from: ev.start)
        let e = cal.dateComponents([.year, .month, .day, .hour], from: ev.end)
        XCTAssertEqual([s.year, s.month, s.day, s.hour], [2026, 12, 13, 16])
        XCTAssertEqual([e.year, e.month, e.day, e.hour], [2027, 1, 10, 16])
        XCTAssertLessThanOrEqual(ev.end.timeIntervalSince(ev.start), 31 * 86_400)
    }

    func test_notStarted_beforeTheWindow_butPreviewed() {
        let e = engine()
        e.refreshTrail(now: before)
        XCTAssertNil(e.trailEvent)
        XCTAssertEqual(SeasonalTrails.featured(before)?.id, ev.id)
    }

    func test_goalsSet_onceInsideTheWindow_sizedToThePlayer() {
        let e = engine()
        e.state.totalTaps = 400
        e.refreshTrail(now: during)
        XCTAssertEqual(e.trailEvent?.id, ev.id)
        XCTAssertEqual(SeasonalTrails.goalAmount(.taps, e.state), Big(2_500))
        XCTAssertEqual(SeasonalTrails.goalAmount(.bigBangs, e.state), Big(1), "a new player's first Big Bang")
        XCTAssertEqual(SeasonalTrails.target(.bestRun, e.state), Big(1e9))
        e.state.totalTaps = 10_000
        e.refreshTrail(now: during)
        XCTAssertEqual(SeasonalTrails.baseline(.taps, e.state), Big(400), "goals don't move once set")
    }

    func test_veteranGoals_scaleUp() {
        let e = engine()
        e.state.totalBigBangs = 300
        e.state.autoBigBangEnabled = true
        e.state.bestRunStardust = Big.fromLog10(500)
        e.refreshTrail(now: during)
        XCTAssertEqual(SeasonalTrails.goalAmount(.bigBangs, e.state), Big(50))
        XCTAssertEqual(SeasonalTrails.target(.bestRun, e.state).log10Value, 502, accuracy: 0.01)
    }

    func test_tapGoal_latches_claimPaysShards_once() {
        let e = engine()
        e.refreshTrail(now: during)
        e.state.totalTaps += 2_500
        e.checkTrail(now: during)
        XCTAssertTrue(SeasonalTrails.isMet(.taps, e.state))
        let shardsBefore = e.state.cosmicShards
        XCTAssertGreaterThan(e.claimTrail(.taps), .zero)
        XCTAssertGreaterThan(e.state.cosmicShards, shardsBefore)
        XCTAssertEqual(e.claimTrail(.taps), .zero, "can't claim twice")
    }

    func test_allFive_payStarAndFrostOrb() {
        let e = engine()
        e.refreshTrail(now: during)
        let stars = e.state.challengeStars
        for step in ev.steps { e.state.solsticeMet.append(step.rawValue) }
        for step in ev.steps { e.claimTrail(step) }
        XCTAssertTrue(e.state.trailOrbsEarned.contains(ev.id))
        XCTAssertEqual(e.state.challengeStars, stars + 1)
        XCTAssertTrue(OrbSkin.frost.isUnlocked(state: e.state, supporter: false))
        XCTAssertFalse(OrbSkin.binary.isUnlocked(state: e.state, supporter: false))
    }

    func test_noProgress_afterTheWindowCloses() {
        let e = engine()
        e.refreshTrail(now: during)
        e.state.totalTaps += 99_999
        e.checkTrail(now: after)
        XCTAssertFalse(SeasonalTrails.isMet(.taps, e.state))
    }

    func test_metButUnclaimed_isPaidWhenTheEventEnds() {
        let e = engine()
        e.refreshTrail(now: during)
        e.state.totalDailyClaims += 5
        e.checkTrail(now: during)
        let shardsBefore = e.state.cosmicShards
        e.refreshTrail(now: after)
        XCTAssertGreaterThan(e.state.cosmicShards, shardsBefore, "the met goal was paid")
        XCTAssertNil(e.trailEvent, "the finished trail is cleared")
        XCTAssertFalse(e.state.trailOrbsEarned.contains(ev.id))
    }

    func test_saveRoundTrip_keepsTrail() throws {
        let e = engine()
        e.refreshTrail(now: during)
        e.state.solsticeMet = ["taps"]
        e.state.trailOrbsEarned = [ev.id]
        let back = try JSONDecoder().decode(GameState.self, from: JSONEncoder().encode(e.state))
        XCTAssertEqual(back.solsticeMet, ["taps"])
        XCTAssertEqual(back.trailEventId, ev.id)
        XCTAssertEqual(back.trailOrbsEarned, [ev.id])
        XCTAssertEqual(back.solsticeTargets.count, ev.steps.count)
    }

    func test_oldSave_decodesWithNoTrail() throws {
        var obj = try JSONSerialization.jsonObject(with: JSONEncoder().encode(GameState())) as! [String: Any]
        for k in ["solsticeBaselines", "solsticeTargets", "solsticeMet", "solsticeClaimed", "solsticeOrbEarned",
                  "trailEventId", "trailOrbsEarned"] {
            obj.removeValue(forKey: k)
        }
        let s = try JSONDecoder().decode(GameState.self, from: JSONSerialization.data(withJSONObject: obj))
        XCTAssertTrue(s.solsticeTargets.isEmpty)
        XCTAssertEqual(s.trailEventId, "")
        XCTAssertTrue(s.trailOrbsEarned.isEmpty)
    }
}
