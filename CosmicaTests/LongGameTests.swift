import XCTest
@testable import Cosmica

/// v3.2 — the long game: huge-number safety, endgame achievements, the weekly
/// challenge, and orb skins.
@MainActor
final class LongGameTests: XCTestCase {
    private func engine(_ state: GameState = GameState()) -> GameEngine {
        GameEngine(state: state, persistence: Persistence.inMemory())
    }

    /// A moment inside week `w` (an hour after it starts).
    private func date(inWeek w: Int) -> Date {
        WeeklyChallenge.epoch.addingTimeInterval(Double(w) * WeeklyChallenge.weekLength + 3600)
    }

    // MARK: - Crash fix

    func test_fragments_pastInt64_doNotTrap() {
        var s = GameState()
        s.absoluteAscendedAt = Date()
        s.cosmicShards = 1e45            // ~5e20 fragments: past Int64.max
        let e = engine(s)
        let f = e.availableFragments
        XCTAssertTrue(f.isFinite)
        XCTAssertGreaterThan(f, 9.3e18)
        XCTAssertTrue(e.canTrueCosmos)
        XCTAssertEqual(e.trueCosmos(), f)
        XCTAssertEqual(e.state.realityFragments, f)
    }

    func test_stardust_neverBecomesInfinite() {
        var s = GameState()
        s.generators[0].count = 25
        s.realityFragments = 1e300        // multiplier stack overflows to ∞
        s.cosmicShards = 1e300
        let e = engine(s)
        XCTAssertFalse(e.state.tapValue.isFinite)
        e.manualTap()
        XCTAssertTrue(e.state.stardust.isFinite)
        XCTAssertEqual(e.state.stardust, GameEngine.ceiling)
        XCTAssertEqual(e.state.lifetimeStardust, GameEngine.ceiling)
    }

    func test_formatter_bigNumbers() {
        XCTAssertEqual(Formatter.short(1.5e63), "1.50Vg")
        XCTAssertEqual(Formatter.short(4.82e71), "4.82e71")
        XCTAssertEqual(Formatter.short(9.999e70), "1.00e71")
        XCTAssertEqual(Formatter.short(1e300), "1.00e300")
        XCTAssertEqual(Formatter.multiplier(1.25), "×1.25")
        XCTAssertEqual(Formatter.multiplier(2e15), "×2.00Qa")
        XCTAssertEqual(Formatter.count(2e6), "2.00M")
    }

    // MARK: - Lifetime counters

    func test_bigBang_countsAndRecordsBestRun() {
        var s = GameState()
        s.lifetimeStardust = 1e12
        let e = engine(s)
        e.bigBang()
        XCTAssertEqual(e.state.totalBigBangs, 1)
        XCTAssertEqual(e.state.bestRunStardust, 1e12)
    }

    func test_oldSave_seedsBigBangCountFromPrestiges() throws {
        var s = GameState()
        s.prestigeCount = 7
        var json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(s)) as! [String: Any]
        json.removeValue(forKey: "totalBigBangs")
        let decoded = try JSONDecoder().decode(GameState.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertEqual(decoded.totalBigBangs, 7)
        XCTAssertEqual(decoded.challengeWeek, -1)
        XCTAssertEqual(decoded.challengeStars, 0)
    }

    // MARK: - Weekly challenge

    func test_weeks_runMondayToMondayUTC() {
        XCTAssertEqual(WeeklyChallenge.week(for: WeeklyChallenge.epoch), 0)
        XCTAssertEqual(WeeklyChallenge.week(for: WeeklyChallenge.epoch.addingTimeInterval(WeeklyChallenge.weekLength - 1)), 0)
        XCTAssertEqual(WeeklyChallenge.week(for: WeeklyChallenge.epoch.addingTimeInterval(WeeklyChallenge.weekLength)), 1)
    }

    func test_refresh_setsThisWeeksChallengeFromTheRotation() {
        let e = engine()
        e.refreshChallenge(now: date(inWeek: 41))
        let pool = WeeklyChallenge.pool(for: e.state)
        XCTAssertEqual(e.challenge?.week, 41)
        XCTAssertEqual(e.challenge?.kind, pool[41 % pool.count])
        XCTAssertFalse(e.state.challengeCompleted)
    }

    /// Sets the first week in the rotation that asks for taps; returns it.
    private func tapWeek(_ e: GameEngine) -> Int {
        let pool = WeeklyChallenge.pool(for: e.state)
        let w = (40...60).first { pool[$0 % pool.count] == .taps }!
        e.refreshChallenge(now: date(inWeek: w))
        return w
    }

    func test_tapChallenge_completesAndClaimsAStar() {
        let e = engine()
        _ = tapWeek(e)
        XCTAssertEqual(e.challenge?.kind, .taps)
        for _ in 0..<1_000 { e.manualTap() }
        e.checkChallenge()
        XCTAssertTrue(e.challengeClaimable)
        let shards = e.claimChallenge()
        XCTAssertGreaterThanOrEqual(shards, 25)
        XCTAssertEqual(e.state.challengeStars, 1)
        XCTAssertEqual(e.state.challengeMultiplier, 1.1, accuracy: 1e-9)
        XCTAssertFalse(e.challengeClaimable)
        XCTAssertEqual(e.claimChallenge(), 0, "can't claim twice")
    }

    func test_unclaimedReward_isGrantedWhenTheWeekRollsOver() {
        let e = engine()
        let w = tapWeek(e)
        for _ in 0..<1_000 { e.manualTap() }
        e.checkChallenge()
        e.refreshChallenge(now: date(inWeek: w + 1))
        XCTAssertEqual(e.state.challengeStars, 1)
        XCTAssertEqual(e.challenge?.week, w + 1)
        XCTAssertFalse(e.state.challengeCompleted)
    }

    func test_streak_countsConsecutiveWeeks() {
        let e = engine()
        let w = tapWeek(e)
        for _ in 0..<1_000 { e.manualTap() }
        e.checkChallenge()
        e.claimChallenge()
        e.refreshChallenge(now: date(inWeek: w + 1))
        // Meet whatever next week asks by pushing every counter past it.
        e.state.totalBigBangs += 100
        e.state.totalTaps += 100_000
        e.state.totalGeneratorsBought += 100_000
        e.state.totalDailyClaims += 10
        e.state.lifetimeStardust = 1e200
        e.checkChallenge()
        e.claimChallenge()
        XCTAssertEqual(e.state.challengeStars, 2)
        XCTAssertEqual(e.state.challengeStreak, 2)
    }

    func test_bestRunChallenge_latchesBeforeABigBangResetsTheRun() {
        var s = GameState()
        s.bestRunStardust = 1e11
        let e = engine(s)
        let pool = WeeklyChallenge.pool(for: e.state)
        let w = (40...60).first { pool[$0 % pool.count] == .beatBestRun }!
        e.refreshChallenge(now: date(inWeek: w))
        XCTAssertEqual(e.challenge?.target, 1e12)
        e.state.lifetimeStardust = 2e12
        e.bigBang()                       // resets the run; must not lose the goal
        XCTAssertEqual(e.state.lifetimeStardust, 0)
        XCTAssertTrue(e.state.challengeCompleted)
    }

    func test_dailyChallenge_neverAsksForMoreDaysThanAreLeft() {
        let s = GameState()
        let pool = WeeklyChallenge.pool(for: s)
        let w = (40...60).first { pool[$0 % pool.count] == .dailyRewards }!
        // Saturday afternoon of that week: under two days left.
        let saturday = WeeklyChallenge.epoch.addingTimeInterval(Double(w) * WeeklyChallenge.weekLength + 5.5 * 86_400)
        let c = WeeklyChallenge.make(week: w, state: s, now: saturday)
        XCTAssertEqual(c.goalAmount, 2)
    }

    // MARK: - Achievements

    func test_newGoals() {
        var s = GameState()
        s.challengeStars = 1
        XCTAssertTrue(AchievementGoal.challengeStars(1).isMet(state: s))
        XCTAssertFalse(AchievementGoal.challengeStars(10).isMet(state: s))
        s.builtWonderIds = Set(WondersCatalog.all.map(\.id))
        XCTAssertTrue(AchievementGoal.wondersBuilt(WondersCatalog.all.count).isMet(state: s))
        s.totalBigBangs = 250
        XCTAssertTrue(AchievementGoal.totalBigBangs(250).isMet(state: s))
    }

    func test_hugeTargets_progressOnALogScale() {
        var s = GameState()
        s.lifetimeStardust = 1e50
        XCTAssertEqual(AchievementGoal.lifetimeStardust(1e100).progress(state: s), 0.5, accuracy: 1e-9)
    }

    func test_achievementIds_areUnique() {
        let ids = AchievementCatalog.all.map(\.id)
        XCTAssertEqual(ids.count, Set(ids).count)
    }

    // MARK: - Orb skins

    func test_orbSkin_resolve() {
        var s = GameState()
        XCTAssertEqual(OrbSkin.resolve(picked: "", legacyGolden: true, state: s, supporter: true), .golden,
                       "3.1 supporters keep their golden orb")
        XCTAssertEqual(OrbSkin.resolve(picked: "", legacyGolden: false, state: s, supporter: true), .tier)
        XCTAssertEqual(OrbSkin.resolve(picked: "void", legacyGolden: true, state: s, supporter: false), .tier,
                       "a locked pick falls back")
        s.cosmosCount = 1
        XCTAssertEqual(OrbSkin.resolve(picked: "nebula", legacyGolden: true, state: s, supporter: false), .nebula)
        s.challengeStars = 5
        XCTAssertTrue(OrbSkin.pulsar.isUnlocked(state: s, supporter: false))
    }
}
