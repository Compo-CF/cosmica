import XCTest
@testable import Cosmica

/// v3.3 "Depth": specialization trade-offs, Stellar ranks, Wonder levels.
@MainActor
final class DepthTests: XCTestCase {
    private func engine(_ state: GameState) -> GameEngine {
        GameEngine(state: state, persistence: Persistence.inMemory())
    }

    // MARK: - Specializations

    func test_overcharged_triplesOutputAndDoublesCost() {
        var g = GameState().generators[0]
        g.count = 25
        let rate = g.unitRate(with: [])
        let cost = g.nextCost
        g.specialization = "overcharged"
        XCTAssertEqual(g.unitRate(with: []), rate * 3, accuracy: rate * 1e-9)
        XCTAssertEqual(g.nextCost, cost * 2, accuracy: cost * 1e-9)
    }

    func test_thrifty_halvesCostAndBuysMore() {
        var g = GameState().generators[0]
        g.count = 25
        let cost = g.nextCost
        let affordable = g.maxAffordable(budget: cost * 50)
        g.specialization = "thrifty"
        XCTAssertEqual(g.nextCost, cost / 2, accuracy: cost * 1e-9)
        XCTAssertGreaterThan(g.maxAffordable(budget: cost * 50), affordable)
    }

    func test_resonant_boostsEveryOtherGeneratorButNotItself() {
        var s = GameState()
        s.generators[0].count = 25
        s.generators[1].count = 10
        let r0 = s.generators[0].ratePerSecond(with: s.upgrades) * CosmicTree.generatorTierMultiplier(0, s.cosmicSkillLevels)
        let r1 = s.generators[1].ratePerSecond(with: s.upgrades) * CosmicTree.generatorTierMultiplier(1, s.cosmicSkillLevels)
        let plain = s.stardustPerSecond
        let k = plain / (r0 + r1)
        s.generators[0].specialization = "attuned"          // Resonant
        XCTAssertEqual(s.stardustPerSecond, (r0 + r1 * 1.10) * k, accuracy: plain * 1e-9)
    }

    func test_nightShift_onlyCountsWhileAway() {
        var s = GameState()
        s.generators[0].count = 25
        let online = s.stardustPerSecond
        s.generators[0].specialization = "steady"           // Night Shift
        XCTAssertEqual(s.stardustPerSecond, online, accuracy: online * 1e-9)
        XCTAssertEqual(s.offlineStardustPerSecond, online * 4, accuracy: online * 1e-9)
    }

    func test_legacySpecIds_stillResolve() {
        for id in ["overcharged", "attuned", "steady"] {
            XCTAssertNotNil(GeneratorSpecCatalog.spec(id: id), id)
        }
    }

    // MARK: - Stellar ranks

    func test_stellarRanks_continuePastMaxAndMultiply() {
        let focus = CosmicTree.skill("focus")!
        XCTAssertTrue(focus.canLevel(from: 12))
        XCTAssertEqual(focus.cost(atLevel: 11), (3 * pow(1.6, 11)).rounded())
        XCTAssertEqual(focus.cost(atLevel: 12), (3 * pow(1.6, 11) * 4).rounded())
        XCTAssertEqual(focus.cost(atLevel: 13), (3 * pow(1.6, 11) * 16).rounded())
        XCTAssertEqual(CosmicTree.focusMultiplier(["focus": 14]), (1 + 0.08 * 12) * 1.1 * 1.1, accuracy: 1e-9)
    }

    func test_utilityNodes_stillCap() {
        let night = CosmicTree.skill("nightwatch")!
        XCTAssertFalse(night.canLevel(from: night.maxLevel))
        XCTAssertEqual(CosmicTree.offlineCapBonus(["nightwatch": 99]), 2 * 3600 * Double(night.maxLevel))
    }

    func test_hugeRankCosts_areFiniteNotATrap() {
        let cost = CosmicTree.skill("focus")!.cost(atLevel: 212)   // rank 200
        XCTAssertTrue(cost.isFinite)
        XCTAssertGreaterThan(cost, 1e100)
    }

    func test_buyingARank_spendsShardsAndRaisesLevel() {
        var s = GameState()
        s.cosmicSkillLevels["focus"] = 12
        s.cosmicShards = 1e6
        let e = engine(s)
        let cost = e.cosmicSkillCost("focus")!
        XCTAssertTrue(e.buyCosmicSkill("focus"))
        XCTAssertEqual(e.state.cosmicSkillLevels["focus"], 13)
        XCTAssertEqual(e.state.cosmicShards, 1e6 - cost, accuracy: 1e-6)
    }

    // MARK: - Kindling

    func test_kindling_triplesEarlyBigBangs() {
        var s = GameState()
        s.lifetimeStardust = 1e12                           // 150 ◈ base
        let e = engine(s)
        XCTAssertTrue(e.kindlingActive)
        XCTAssertEqual(e.availableShards, 450)
        e.bigBang()
        XCTAssertEqual(e.state.cosmicShards, 450)
        XCTAssertEqual(e.state.lifetimeCosmicShards, 450)
    }

    func test_kindling_onlyTriplesUpToTheCap() {
        let cap = PrestigeCalculator.kindlingCap
        // 900 ◈ base with 5,700 earned: 300 fits under the cap (100 base ×3), the rest is plain.
        XCTAssertEqual(PrestigeCalculator.kindled(900, lifetimeShards: cap - 300, cosmosCount: 0), 300 + 800)
        // A giant first run is not a windfall.
        XCTAssertEqual(PrestigeCalculator.kindled(1e6, lifetimeShards: 0, cosmosCount: 0), 1e6 + cap * 2 / 3, accuracy: 1e-6)
        // Crossing the cap never pays less than staying just under it.
        let under = PrestigeCalculator.kindled(99, lifetimeShards: cap - 300, cosmosCount: 0)
        let over = PrestigeCalculator.kindled(101, lifetimeShards: cap - 300, cosmosCount: 0)
        XCTAssertGreaterThan(over, under)
    }

    func test_kindling_endsAtTheCapAndAfterTrueCosmos() {
        XCTAssertEqual(PrestigeCalculator.kindled(150, lifetimeShards: PrestigeCalculator.kindlingCap, cosmosCount: 0), 150)
        XCTAssertEqual(PrestigeCalculator.kindled(150, lifetimeShards: 0, cosmosCount: 1), 150)
        var s = GameState()
        s.cosmosCount = 1
        s.lifetimeStardust = 1e12
        XCTAssertFalse(engine(s).kindlingActive)
        XCTAssertEqual(engine(s).availableShards, 150)
    }

    // MARK: - Wonder levels

    func test_wonder_buildsThenLevelsUpAtTenTimesTheCost() {
        var s = GameState()
        s.cosmosCount = 1
        s.cosmicShards = 1e6
        let e = engine(s)
        XCTAssertEqual(e.wonderCost("chronosphere"), 5_000)
        XCTAssertTrue(e.buildWonder(id: "chronosphere"))
        XCTAssertEqual(e.state.wonderLevel("chronosphere"), 1)
        XCTAssertEqual(e.wonderCost("chronosphere"), 50_000)
        XCTAssertTrue(e.buildWonder(id: "chronosphere"))
        XCTAssertEqual(e.state.wonderLevel("chronosphere"), 2)
        XCTAssertEqual(e.state.wonderOfflineCapBonus, 24 * 3600)
        XCTAssertTrue(e.state.builtWonderIds.contains("chronosphere"))
    }

    func test_oneShotWonder_stopsAtOne() {
        var s = GameState()
        s.cosmosCount = 12
        s.cosmicShards = 1e9
        let e = engine(s)
        XCTAssertTrue(e.buildWonder(id: "time_lens"))
        XCTAssertNil(e.wonderCost("time_lens"))
        XCTAssertFalse(e.buildWonder(id: "time_lens"))
    }

    func test_timeLens_doublesOfflineRate() {
        var s = GameState()
        s.generators[0].count = 25
        let online = s.stardustPerSecond
        s.wonderLevels["time_lens"] = 1
        XCTAssertEqual(s.offlineStardustPerSecond, online * 2, accuracy: online * 1e-9)
    }

    func test_preDepthSave_treatsBuiltWondersAsLevelOne() throws {
        var s = GameState()
        s.builtWonderIds = ["voidkeeper"]
        var json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(s)) as! [String: Any]
        json.removeValue(forKey: "wonderLevels")
        let old = try JSONDecoder().decode(GameState.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertEqual(old.wonderLevel("voidkeeper"), 1)
        XCTAssertEqual(old.wonderBigBangYieldMultiplier, 1.5, accuracy: 1e-12)
    }
}
