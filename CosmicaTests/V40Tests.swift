import XCTest
@testable import Cosmica

/// v4.0 — rating-prompt rules (plan phase 5) and save compatibility with Big.
@MainActor
final class V40Tests: XCTestCase {
    private let day: TimeInterval = 86_400
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    // MARK: Rating prompt

    func test_review_waitsForAnInvestedPlayer() {
        let installedYesterday = now.addingTimeInterval(-1 * day)
        let installedLastWeek = now.addingTimeInterval(-7 * day)
        XCTAssertFalse(ReviewPrompter.isEligible(now: now, installedAt: installedYesterday, bigBangs: 50, previousAsks: []))
        XCTAssertFalse(ReviewPrompter.isEligible(now: now, installedAt: installedLastWeek, bigBangs: 2, previousAsks: []))
        XCTAssertTrue(ReviewPrompter.isEligible(now: now, installedAt: installedLastWeek, bigBangs: 3, previousAsks: []))
    }

    func test_review_atMostThreeAYear_ninetyDaysApart() {
        let installed = now.addingTimeInterval(-400 * day)
        let ok = { (asks: [Date]) in ReviewPrompter.isEligible(now: self.now, installedAt: installed, bigBangs: 10, previousAsks: asks) }
        XCTAssertFalse(ok([now.addingTimeInterval(-30 * day)]))                       // too soon
        XCTAssertTrue(ok([now.addingTimeInterval(-91 * day)]))
        XCTAssertFalse(ok([-300, -200, -100].map { now.addingTimeInterval($0 * day) })) // three this year
        XCTAssertTrue(ok([-500, -200, -100].map { now.addingTimeInterval($0 * day) }))  // one fell out of the year
    }

    // MARK: Save compatibility

    /// A pre-4.0 save (plain JSON numbers) loads into Big fields unchanged.
    func test_pre40Save_decodesIntoBig() throws {
        var old = GameState()
        old.stardust = Big(1.5e40)
        old.cosmicShards = Big(12_345)
        old.voidSparks = Big(7)
        let data = try JSONEncoder().encode(old)
        let text = String(data: data, encoding: .utf8) ?? ""
        XCTAssertTrue(text.contains("\"cosmicShards\":12345"), "still a plain number on disk")
        let loaded = try JSONDecoder().decode(GameState.self, from: data)
        XCTAssertEqual(loaded.stardust, Big(1.5e40))
        XCTAssertEqual(loaded.cosmicShards, 12_345)
        XCTAssertEqual(loaded.voidSparks, 7)
    }

    /// Past Double's range the save round-trips through a string.
    func test_hugeValues_roundTripThroughTheSave() throws {
        var s = GameState()
        s.realityFragments = Big(mantissa: 2.5, exponent: 1_234)
        let loaded = try JSONDecoder().decode(GameState.self, from: JSONEncoder().encode(s))
        XCTAssertEqual(loaded.realityFragments, Big(mantissa: 2.5, exponent: 1_234))
    }

    // MARK: Omniverse

    private func engine(_ state: GameState = GameState()) -> GameEngine {
        GameEngine(state: state, persistence: Persistence.inMemory())
    }

    func test_dilation_onlyBitesPastTheDoor() {
        XCTAssertEqual(Dilation.apply(Big(1e300), strength: 0.5), Big(1e300))
        let t = Dilation.threshold.log10Value
        let x = Big.fromLog10(t + 200)                       // 200 orders past the door
        XCTAssertEqual(Dilation.apply(x, strength: 0.5).log10Value, t + 100, accuracy: 1e-9)
        XCTAssertEqual(Dilation.apply(x, strength: 0.62).log10Value, t + 124, accuracy: 1e-9)
    }

    func test_echoes_oneAtTheDoor_tenfoldPerHundredOrders() {
        XCTAssertEqual(OmniverseCalculator.echoesEarned(bestRun: Big(1e300)), 0)
        XCTAssertEqual(OmniverseCalculator.echoesEarned(bestRun: Dilation.threshold), 1)
        let t = Dilation.threshold.log10Value
        XCTAssertEqual(OmniverseCalculator.echoesEarned(bestRun: Big.fromLog10(t + 100)), 10)
        XCTAssertEqual(OmniverseCalculator.echoesEarned(bestRun: Big.fromLog10(t + 300)), 1_000)
        XCTAssertGreaterThan(OmniverseCalculator.bestRunRequired(forEchoes: Big(10)), Dilation.threshold)
    }

    func test_ceilingIsGone_andTheDoorOpensPastIt() {
        var s = GameState()
        s.generators[0].count = 25
        s.realityFragments = Big(1e300)
        s.cosmicShards = Big(1e300)
        let e = engine(s)
        XCTAssertFalse(e.omniverseUnlocked)
        e.manualTap()
        XCTAssertTrue(e.state.lifetimeStardust > Dilation.threshold)
        e.applyTimeWarp(hours: 0.01)                          // any gain path checks the door
        XCTAssertTrue(e.omniverseUnlocked)
        XCTAssertTrue(e.showOmniverseDoor)
    }

    func test_omniverseCollapse_resetsTheMultiverse_keepsWondersAndRestartsTheGoal() {
        var s = GameState()
        s.omniverseDoorOpen = true
        s.lifetimeStardust = Big.fromLog10(Dilation.threshold.log10Value + 100)   // 10 Echoes
        s.voidSparks = Big(1_000)
        s.realityFragments = Big(1e9)
        s.cosmosCount = 40
        s.cosmosSinceOmniverse = 40
        s.multiverseCount = 12
        s.wonderLevels = ["stellar_forge": 3, VoidWonderCatalog.furnaceId: 4]
        s.builtWonderIds = ["stellar_forge"]
        s.omniverseLevels = [OmniverseTree.sparkMemoryId: 2]  // keep 20% of sparks
        let e = engine(s)
        XCTAssertEqual(e.availableEchoes, 10)
        XCTAssertEqual(e.omniverseCollapse(), 10)
        XCTAssertEqual(e.state.echoes, 10)
        XCTAssertEqual(e.state.omniverseCount, 1)
        XCTAssertEqual(e.state.voidSparks, 200)
        XCTAssertEqual(e.state.realityFragments, 0)
        XCTAssertEqual(e.state.cosmosSinceOmniverse, 0)
        XCTAssertEqual(e.state.cosmosCount, 40)               // unlocks keep working
        XCTAssertEqual(e.state.multiverseCount, 12)
        XCTAssertEqual(e.state.wonderLevel("stellar_forge"), 3)   // Cosmic Wonders kept
        XCTAssertEqual(e.state.wonderLevel(VoidWonderCatalog.furnaceId), 0)
        XCTAssertEqual(e.state.lifetimeStardust, 0)
        XCTAssertEqual(e.cosmosGoal, 0)                        // first cosmos of the new ladder
        XCTAssertEqual(e.omniverseCollapse(), 0)               // nothing left to claim
    }

    func test_echoes_multiplyProduction_andVeilRaisesDilation() {
        var s = GameState()
        s.generators[0].count = 25
        let base = s.stardustPerSecond
        s.echoes = Big(9)
        XCTAssertEqual(s.stardustPerSecond, base * 10, accuracy: base * 1e-9)
        s.omniverseLevels = [OmniverseTree.veilId: 40]         // capped at 12 levels' worth
        XCTAssertEqual(s.dilationStrength, Dilation.maxStrength, accuracy: 1e-12)
    }

    func test_buyOmniverseNode_spendsEchoes_andStopsAtMax() {
        var s = GameState()
        s.echoes = Big(100)
        let e = engine(s)
        XCTAssertEqual(e.omniverseNodeCost(OmniverseTree.veilId), 5)
        XCTAssertTrue(e.buyOmniverseNode(id: OmniverseTree.veilId))
        XCTAssertEqual(e.state.echoes, 95)
        XCTAssertEqual(e.omniverseNodeCost(OmniverseTree.veilId), 15)
        XCTAssertTrue(e.buyOmniverseNode(id: OmniverseTree.autoCosmosId))
        XCTAssertNil(e.omniverseNodeCost(OmniverseTree.autoCosmosId))     // one level only
        XCTAssertFalse(e.buyOmniverseNode(id: OmniverseTree.autoCosmosId))
    }

    func test_cosmicAutopilot_trueCosmosesOnlyWhenItDoubles() {
        var s = GameState()
        s.absoluteAscendedAt = Date()
        s.cosmicShards = Big(1e8)                              // 500 fragments
        s.realityFragments = Big(1_000)                        // would not double
        s.omniverseLevels = [OmniverseTree.autoCosmosId: 1]
        let e = engine(s)
        e.omniverseAutomationStep(now: Date())
        XCTAssertEqual(e.state.cosmosCount, 0)
        e.state.realityFragments = Big(100)
        e.omniverseAutomationStep(now: Date().addingTimeInterval(60))
        XCTAssertEqual(e.state.cosmosCount, 1)
    }

    // MARK: Rifts

    private func riftReady() -> GameEngine {
        var s = GameState()
        s.omniverseCount = 1
        s.generators[0].count = 25
        s.bestRunStardust = Big.fromLog10(400)   // (a 1e400 literal is +inf as a Double)
        return engine(s)
    }

    func test_rift_goalFollowsYourBest_andEnteringResetsTheRun() {
        let e = riftReady()
        XCTAssertEqual(e.riftGoalLog(for: RiftCatalog.dimStarsId), 240)        // 60% of 1e400
        e.state.stardust = Big(1e50)
        XCTAssertTrue(e.enterRift(RiftCatalog.dimStarsId))
        XCTAssertEqual(e.state.activeRiftId, RiftCatalog.dimStarsId)
        XCTAssertEqual(e.state.riftGoalLog, 240, accuracy: 1e-9)
        XCTAssertTrue(e.state.stardust < 1e50)
        XCTAssertFalse(e.enterRift(RiftCatalog.loneHandId))                       // one at a time
    }

    func test_rift_completesATier_andThenAsksMore() {
        let e = riftReady()
        e.enterRift(RiftCatalog.loneHandId)
        e.state.lifetimeStardust = Big.fromLog10(241)
        e.applyOffline()                                                          // runs the checks even at zero production
        XCTAssertNil(e.state.activeRiftId)
        XCTAssertEqual(e.state.riftTier(RiftCatalog.loneHandId), 1)
        XCTAssertEqual(e.completedRiftId, RiftCatalog.loneHandId)
        XCTAssertEqual(e.riftGoalLog(for: RiftCatalog.loneHandId), 320)           // 80% of the 1e400 best
    }

    func test_rift_rules() {
        var s = GameState()
        s.generators[0].count = 25
        s.generators[9].count = 25
        s.realityFragments = Big(1e6)
        let free = s.stardustPerSecond
        s.activeRiftId = RiftCatalog.dimStarsId
        XCTAssertTrue(s.stardustPerSecond < free)                                 // generator 10 is dark
        s.activeRiftId = RiftCatalog.silentVoidId
        XCTAssertEqual(s.realityFragmentMultiplier, 1)
        s.activeRiftId = RiftCatalog.shortNightId
        XCTAssertEqual(s.offlineStardustPerSecond, 0)
        s.activeRiftId = RiftCatalog.loneHandId
        let tapRift = s.tapValue
        s.activeRiftId = nil
        XCTAssertEqual(tapRift, s.tapValue * 100, accuracy: tapRift * 1e-9)
    }

    func test_rift_rewards() {
        var s = GameState()
        s.riftTiers = [RiftCatalog.heavyVeilId: 3, RiftCatalog.loneHandId: 2]
        s.omniverseLevels = [OmniverseTree.veilId: 12]
        XCTAssertEqual(s.dilationStrength, 0.641, accuracy: 1e-12)
        XCTAssertLessThan(s.dilationStrength, 0.65)                               // the runaway line
        s.generators[0].count = 25
        let tap = s.tapValue
        s.riftTiers[RiftCatalog.loneHandId] = 0
        XCTAssertEqual(tap, s.tapValue * 25, accuracy: tap * 1e-9)
    }

    /// The CI screenshot save must survive the engine's tick paths and every formatter.
    func test_demoSave_runsTheEngineWithoutTrapping() {
        let e = engine(DemoMode.state())
        _ = e.state.stardustPerSecond
        _ = e.state.tapValue
        _ = e.availableShards; _ = e.availableFragments; _ = e.availableSparks; _ = e.availableEchoes
        e.manualTap()
        e.applyTimeWarp(hours: 1)          // runs the door / achievement / challenge checks
        XCTAssertTrue(e.state.lifetimeStardust > Dilation.threshold)
        e.omniverseAutomationStep(now: Date())   // the demo owns no autopilot: nothing resets
        XCTAssertEqual(e.state.cosmosCount, 64)
        e.state.omniverseLevels[OmniverseTree.autoCosmosId] = 1
        e.omniverseAutomationStep(now: Date().addingTimeInterval(60))
        XCTAssertEqual(e.state.cosmosCount, 65)                // with it, a True Cosmos runs
        for g in e.state.generators { _ = Formatter.short(g.nextCost); _ = g.maxAffordable(budget: e.state.stardust) }
        for s in [e.state.stardust, e.state.cosmicShards, e.state.realityFragments, e.state.stardustPerSecond] {
            _ = Formatter.short(s); _ = Formatter.count(s); _ = Formatter.multiplier(s)
        }
        for a in AchievementCatalog.all { _ = a.goal.progress(state: e.state) }
    }

    func test_formatter_pastDouble() {
        XCTAssertEqual(Formatter.short(Big(1_500)), "1.50K")
        XCTAssertEqual(Formatter.short(Big(mantissa: 4.82, exponent: 71)), "4.82e71")
        XCTAssertEqual(Formatter.short(Big(mantissa: 1.234, exponent: 4_567)), "1.23e4567")
        XCTAssertEqual(Formatter.short(Big(mantissa: 1.234, exponent: 12_345)), "1.23e12,345")
    }
}
