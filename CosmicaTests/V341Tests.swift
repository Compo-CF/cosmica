import XCTest
@testable import Cosmica

/// v3.4.1 — endgame pacing (review: "cycle prestiges ... in literal minutes",
/// "spamming 20 cosmic resets"), the Offline Catch-Up fix, and the daily ×2.
@MainActor
final class V341Tests: XCTestCase {
    private func engine(_ state: GameState = GameState()) -> GameEngine {
        GameEngine(state: state, persistence: Persistence.inMemory())
    }

    // MARK: Cosmos Goal

    func test_goal_isAbsoluteGatedFirst_thenTenThousandTimesPerCosmos_cappedAtTheCeiling() {
        XCTAssertEqual(CosmosCalculator.goal(cosmosCount: 0), 0)
        XCTAssertEqual(CosmosCalculator.goal(cosmosCount: 1), 1e40, accuracy: 1e26)
        XCTAssertEqual(CosmosCalculator.goal(cosmosCount: 5), 1e56, accuracy: 1e42)
        XCTAssertEqual(CosmosCalculator.goal(cosmosCount: 66), 1e300, accuracy: 1e286)
        // v4.0 — no ceiling: the ladder keeps climbing (it restarts per Omniverse instead).
        XCTAssertEqual(CosmosCalculator.goal(cosmosCount: 500).log10Value, 2_036, accuracy: 1e-9)
        XCTAssertEqual(CosmosCalculator.goal(cosmosCount: 10_000).log10Value, 40_036, accuracy: 1e-9)
    }

    func test_trueCosmos_waitsForTheGoal_andABigBangRemembersTheRun() {
        var s = GameState()
        s.absoluteAscendedAt = Date()
        s.cosmosCount = 3                       // goal 1e48
        s.cosmosSinceOmniverse = 3              // v4.0 — the goal reads this (a decoded pre-4.0 save copies cosmosCount)
        s.cosmicShards = Big(1e8)
        s.lifetimeStardust = Big(1e47)
        let e = engine(s)
        XCTAssertGreaterThan(e.availableFragments, 0)
        XCTAssertFalse(e.cosmosGoalMet)
        XCTAssertFalse(e.canTrueCosmos)
        XCTAssertEqual(e.trueCosmos(), 0)

        e.state.lifetimeStardust = Big(2e48)
        XCTAssertTrue(e.canTrueCosmos)
        // A Big Bang resets the run, but the cosmos remembers it reached the goal.
        XCTAssertGreaterThan(e.bigBang(), 0)
        XCTAssertEqual(e.state.lifetimeStardust, 0)
        XCTAssertTrue(e.cosmosGoalMet)

        XCTAssertGreaterThan(e.trueCosmos(), 0)
        XCTAssertEqual(e.state.cosmosCount, 4)
        XCTAssertEqual(e.state.cosmosBestRun, 0)  // the next cosmos starts over
        XCTAssertFalse(e.cosmosGoalMet)
    }

    func test_preUpdateSave_keepsItsBestRunTowardTheGoal() throws {
        var s = GameState()
        s.bestRunStardust = Big(3e60)
        var json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(s)) as! [String: Any]
        for k in ["cosmosBestRun", "lastAwaySeconds", "lastAwayPaidSeconds"] { json.removeValue(forKey: k) }
        let old = try JSONDecoder().decode(GameState.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertEqual(old.cosmosBestRun, 3e60)
        XCTAssertEqual(old.lastAwaySeconds, 0)
    }

    // MARK: Softer late curves

    func test_fragments_unchangedBelowABillionShards_gentlerAbove_andContinuous() {
        XCTAssertEqual(CosmosCalculator.fragmentsEarned(cosmicShards: Big(1e6)), 50)
        XCTAssertEqual(CosmosCalculator.fragmentsEarned(cosmicShards: Big(1e8)), 500)
        let atKnee = CosmosCalculator.rawFragments(Big(1e9))
        XCTAssertEqual(CosmosCalculator.rawFragments(Big(1e9 * 1.000001)), atKnee, accuracy: atKnee.double * 1e-5)
        // 1e19 shards: √ would pay 5e9; the gentler curve pays ~5e7.
        let late = CosmosCalculator.fragmentsEarned(cosmicShards: Big(1e19))
        XCTAssertLessThan(late, 1e8)
        XCTAssertGreaterThan(late, 1e7)
        // The inverse agrees on both sides of the knee.
        for f in [400.0, 1_581, 5_000, 1e7] {
            let need = CosmosCalculator.shardsRequired(forFragments: Big(f))
            XCTAssertGreaterThanOrEqual(CosmosCalculator.rawFragments(need * 1.0000001), f * 0.99999, "f=\(f)")
        }
    }

    func test_sparkFragmentBonus_growsWithTheSquareRoot() {
        XCTAssertEqual(MultiverseCalculator.fragmentMultiplier(sparks: Big(0)), 1)
        XCTAssertEqual(MultiverseCalculator.fragmentMultiplier(sparks: Big(1)), 1.25, accuracy: 1e-12)
        XCTAssertEqual(MultiverseCalculator.fragmentMultiplier(sparks: Big(100)), 3.5, accuracy: 1e-12)
    }

    func test_newWonderLevels_costMore_builtLevelsKeepTheirEffect() {
        var s = GameState()
        s.wonderLevels = ["stellar_forge": 5]
        XCTAssertEqual(s.wonderForgeMultiplier, 32)          // unchanged: ×2 per level
        let forge = WondersCatalog.wonder(id: "stellar_forge")!
        XCTAssertEqual(forge.cost(toReachLevel: 6), 1e10 * 1e10, accuracy: 1e6)
        let furnace = VoidWonderCatalog.wonder(id: VoidWonderCatalog.furnaceId)!
        XCTAssertEqual(furnace.cost(toReachLevel: 3), 3 * 81)
        let prism = VoidWonderCatalog.wonder(id: VoidWonderCatalog.prismId)!
        XCTAssertEqual(prism.cost(toReachLevel: 2), 80)
    }

    // MARK: Offline Catch-Up

    private func awayState() -> GameState {
        var s = GameState()
        s.generators[0].count = 50
        s.lastSeen = Date().addingTimeInterval(-30 * 3600)   // 30 hours away
        return s
    }

    func test_catchUp_paysWhatTheCapCutOff_once() {
        let e = engine(awayState())
        let welcome = e.applyOffline()
        XCTAssertTrue(welcome.wasCapped)
        XCTAssertEqual(e.state.lastAwayPaidSeconds, OfflineAccrual.baseCap, accuracy: 1)

        // A save in between (lastSeen moves) must not shrink what's owed.
        e.save()
        let rate = e.state.offlineStardustPerSecond * OfflineAccrual.offlineRate
        let expected = rate * (OfflineAccrual.extendedCap - OfflineAccrual.baseCap)
        XCTAssertEqual(e.offlineCatchUpAmount(cap: e.adCatchUpCap), expected, accuracy: expected * 1e-3)

        let before = e.state.stardust
        let r = e.applyOfflineCatchUp(cap: e.adCatchUpCap)
        XCTAssertEqual(r.stardustEarned, expected, accuracy: expected * 1e-3)
        XCTAssertEqual(e.state.stardust - before, r.stardustEarned, accuracy: expected * 1e-3)
        // Claimed: the ad has nothing left; the 7-day IAP still covers the last 6 hours.
        XCTAssertEqual(e.offlineCatchUpAmount(cap: e.adCatchUpCap), 0)
        // At today's rate: the 16 hours just paid lifted the run a tier (×1.25).
        let rateNow = e.state.offlineStardustPerSecond * OfflineAccrual.offlineRate
        XCTAssertEqual(e.offlineCatchUpAmount(cap: e.iapCatchUpCap), rateNow * 6 * 3600, accuracy: rateNow * 10)
    }

    func test_shortAbsence_leavesNothingToSell_andAQuickSwitchKeepsTheClaim() {
        var s = GameState()
        s.generators[0].count = 50
        s.lastSeen = Date().addingTimeInterval(-3600)
        let e = engine(s)
        e.applyOffline()
        XCTAssertEqual(e.offlineCatchUpAmount(cap: e.iapCatchUpCap), 0)

        let long = engine(awayState())
        long.applyOffline()
        let owed = long.offlineCatchUpAmount(cap: long.adCatchUpCap)
        long.state.lastSeen = Date().addingTimeInterval(-20)    // back after a 20 s app switch
        long.applyOffline()
        XCTAssertEqual(long.offlineCatchUpAmount(cap: long.adCatchUpCap), owed, accuracy: owed * 1e-3)
    }

    // MARK: Daily ×2

    func test_dailyDouble_doublesEveryPart() {
        var s = GameState()
        s.generators[0].count = 50
        let e = engine(s)
        let plain = e.previewDailyReward()
        let doubled = e.claimDaily(multiplier: 2)
        XCTAssertEqual(doubled.stardust, plain.stardust * 2, accuracy: 1e-6)
        XCTAssertEqual(doubled.cosmicShards, plain.cosmicShards * 2)
        XCTAssertEqual(doubled.boostHours, plain.boostHours * 2)
        XCTAssertFalse(e.dailyRewardAvailable)
    }
}
