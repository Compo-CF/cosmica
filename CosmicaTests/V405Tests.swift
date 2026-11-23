import XCTest
@testable import Cosmica

/// v4.0.5 — Binary Stars (15 Jan – 15 Feb 2027), the second Seasonal Trail, and the hand-off
/// from the Winter Solstice Trail (including saves written by 4.0.4).
@MainActor
final class V405Tests: XCTestCase {
    private func engine() -> GameEngine {
        GameEngine(state: GameState(), persistence: Persistence.inMemory())
    }
    private let solstice = SeasonalTrails.solstice
    private let binary = SeasonalTrails.binaryStars
    private var during: Date { binary.start.addingTimeInterval(86_400) }

    func test_window_matchesTheInAppEvent_andCoversValentines() {
        var cal = Calendar(identifier: .gregorian); cal.timeZone = TimeZone(identifier: "UTC")!
        let s = cal.dateComponents([.year, .month, .day, .hour], from: binary.start)
        let e = cal.dateComponents([.year, .month, .day, .hour], from: binary.end)
        XCTAssertEqual([s.year, s.month, s.day, s.hour], [2027, 1, 15, 8])
        XCTAssertEqual([e.year, e.month, e.day, e.hour], [2027, 2, 15, 7])
        XCTAssertLessThan(binary.end.timeIntervalSince(binary.start), 31 * 86_400, "Apple's 31-day limit")
        XCTAssertGreaterThanOrEqual(binary.start, solstice.end, "trails never overlap")
    }

    func test_banner_previewsBinaryStars_betweenTheTrails() {
        let gap = solstice.end.addingTimeInterval(3600)
        XCTAssertNil(SeasonalTrails.open(gap))
        XCTAssertEqual(SeasonalTrails.featured(gap)?.id, binary.id)
        XCTAssertEqual(SeasonalTrails.featured(during)?.id, binary.id)
        XCTAssertNil(SeasonalTrails.featured(binary.end.addingTimeInterval(60)))
    }

    func test_goals_areTwinSized() {
        let e = engine()
        e.state.totalDailyClaims = 30
        e.refreshTrail(now: during)
        XCTAssertEqual(e.trailEvent?.id, binary.id)
        XCTAssertEqual(SeasonalTrails.goalAmount(.dailies, e.state), Big(7))
        XCTAssertEqual(SeasonalTrails.goalAmount(.weeklies, e.state), Big(2))
        XCTAssertEqual(SeasonalTrails.goalAmount(.bigBangs, e.state), Big(2), "a new player's first two Big Bangs")
        XCTAssertNil(e.state.solsticeTargets[TrailStep.generators.rawValue], "Binary Stars has no generator goal")
    }

    func test_weeklyGoal_countsChallengeStars() {
        let e = engine()
        e.state.challengeStars = 4
        e.refreshTrail(now: during)
        e.state.challengeStars = 6
        e.checkTrail(now: during)
        XCTAssertTrue(SeasonalTrails.isMet(.weeklies, e.state))
    }

    func test_allFive_payBinaryOrb() {
        let e = engine()
        e.refreshTrail(now: during)
        for step in binary.steps { e.state.solsticeMet.append(step.rawValue) }
        for step in binary.steps { e.claimTrail(step) }
        XCTAssertTrue(OrbSkin.binary.isUnlocked(state: e.state, supporter: false))
        XCTAssertFalse(OrbSkin.frost.isUnlocked(state: e.state, supporter: false))
    }

    func test_solsticeHandsOffToBinaryStars_keepingTheFrostOrb() {
        let e = engine()
        e.refreshTrail(now: solstice.start.addingTimeInterval(60))
        for step in solstice.steps { e.state.solsticeMet.append(step.rawValue) }
        for step in solstice.steps.dropLast() { e.claimTrail(step) }   // last one left unclaimed
        e.refreshTrail(now: during)   // app opened for the first time after Solstice ended
        XCTAssertTrue(e.state.trailOrbsEarned.contains(solstice.id), "unclaimed goal paid at close, orb earned")
        XCTAssertEqual(e.trailEvent?.id, binary.id)
        XCTAssertTrue(e.state.solsticeMet.isEmpty && e.state.solsticeClaimed.isEmpty, "fresh goals")
        XCTAssertTrue(OrbSkin.frost.isUnlocked(state: e.state, supporter: false))
    }

    /// A save written by 4.0.4 mid-Solstice: no `trailEventId` / `trailOrbsEarned` keys.
    func test_404Save_migratesToTheSolsticeTrail() throws {
        let e = engine()
        e.refreshTrail(now: solstice.start.addingTimeInterval(60))
        e.state.solsticeOrbEarned = true
        var obj = try JSONSerialization.jsonObject(with: JSONEncoder().encode(e.state)) as! [String: Any]
        obj.removeValue(forKey: "trailEventId"); obj.removeValue(forKey: "trailOrbsEarned")
        let s = try JSONDecoder().decode(GameState.self, from: JSONSerialization.data(withJSONObject: obj))
        XCTAssertEqual(s.trailEventId, solstice.id)
        XCTAssertEqual(s.trailOrbsEarned, [solstice.id])
    }
}
