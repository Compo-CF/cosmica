import XCTest
@testable import Cosmica

/// v3.4 — Multiverse Collapse, Void Wonders, premium bundles, shard packs,
/// the free daily Time Warp and the anonymous Shop counter.
@MainActor
final class V34Tests: XCTestCase {
    private func engine(_ state: GameState = GameState()) -> GameEngine {
        GameEngine(state: state, persistence: Persistence.inMemory())
    }

    // MARK: Multiverse math

    func test_sparks_needAThousandFragments_thenGrowWithTheSquareRoot() {
        XCTAssertEqual(MultiverseCalculator.sparksEarned(realityFragments: 999), 0)
        XCTAssertEqual(MultiverseCalculator.sparksEarned(realityFragments: 1_000), 5)
        XCTAssertEqual(MultiverseCalculator.sparksEarned(realityFragments: 4_000), 10)
        XCTAssertEqual(MultiverseCalculator.sparksEarned(realityFragments: 1e6), 158)
        XCTAssertEqual(MultiverseCalculator.nextSparkThreshold(realityFragments: 0), 1_000)
        XCTAssertEqual(MultiverseCalculator.nextSparkThreshold(realityFragments: 1_000), 1_440, accuracy: 1e-6)
        XCTAssertEqual(MultiverseCalculator.progressToNextSpark(realityFragments: 500), 0.5, accuracy: 1e-9)
    }

    /// v3.4.1: still a dip, not a trap, but a deeper one. A small collapse is
    /// earned back by the first True Cosmos; a big one keeps a real share of
    /// its power and climbs back over a few cosmoi (the fragment bonus now
    /// grows with √sparks so collapses stop compounding ×100–1,000 each).
    func test_collapse_isADipNotATrap() {
        for f in [1_000.0, 10_000, 100_000, 1_000_000] {
            let s = MultiverseCalculator.sparksEarned(realityFragments: f)
            let before = CosmosCalculator.multiplier(fragments: f)
            let firstCosmos = 50 * MultiverseCalculator.fragmentMultiplier(sparks: s)
            let after = CosmosCalculator.multiplier(fragments: firstCosmos) * MultiverseCalculator.stardustMultiplier(sparks: s)
            XCTAssertGreaterThan(after, before * 0.05, "F=\(f)")
            if f == 1_000 { XCTAssertGreaterThan(after, before) }
        }
    }

    func test_multiverseCollapse_tradesFragmentsForSparks_keepsWhatShouldSurvive() {
        var s = GameState()
        s.cosmosCount = 10
        s.realityFragments = 4_000
        s.lifetimeRealityFragments = 4_000
        s.cosmicShards = 5e6
        s.absoluteAscendedAt = Date()
        s.wonderLevels = ["chronosphere": 2]
        s.builtWonderIds = ["chronosphere"]
        s.challengeStars = 3
        s.cosmicSkillLevels = ["focus": 3, "autonomy_nexus": 1]
        let e = engine(s)
        XCTAssertTrue(e.canCollapseMultiverse)
        XCTAssertEqual(e.multiverseCollapse(), 10)
        XCTAssertEqual(e.state.voidSparks, 10)
        XCTAssertEqual(e.state.lifetimeVoidSparks, 10)
        XCTAssertEqual(e.state.multiverseCount, 1)
        XCTAssertEqual(e.state.realityFragments, 0)
        XCTAssertEqual(e.state.lifetimeRealityFragments, 4_000)
        XCTAssertEqual(e.state.cosmicShards, 0)
        XCTAssertEqual(e.state.cosmosCount, 10)
        XCTAssertEqual(e.state.wonderLevel("chronosphere"), 2)
        XCTAssertEqual(e.state.challengeStars, 3)
        XCTAssertTrue(e.state.hasAbsoluteAscended)
        XCTAssertEqual(e.state.cosmicSkillLevels, ["autonomy_nexus": 1])
        // Nothing left to collapse until fragments are earned again.
        XCTAssertFalse(e.canCollapseMultiverse)
        XCTAssertEqual(e.multiverseCollapse(), 0)
    }

    func test_multiverse_locksBelowTenCosmoi() {
        var s = GameState()
        s.cosmosCount = 9
        s.realityFragments = 50_000
        XCTAssertFalse(engine(s).canCollapseMultiverse)
    }

    func test_sparks_multiplyStardustAndFragments() {
        var s = GameState()
        s.generators[0].count = 25
        let base = s.stardustPerSecond
        s.voidSparks = 4
        XCTAssertEqual(s.stardustPerSecond, base * 11, accuracy: base * 1e-9)   // 1 + 2.5·4

        var t = GameState()
        t.absoluteAscendedAt = Date()
        t.cosmicShards = 1e6                  // 50 fragments before bonuses
        XCTAssertEqual(engine(t).availableFragments, 50)
        t.voidSparks = 4                      // v3.4.1: ×(1 + 0.25·√4) = ×1.5
        XCTAssertEqual(engine(t).availableFragments, 75)
    }

    // MARK: Void Wonders

    func test_voidWonders_costSparks_andApplyTheirEffects() {
        var s = GameState()
        s.multiverseCount = 1
        s.voidSparks = 10
        s.absoluteAscendedAt = Date()
        let e = engine(s)
        XCTAssertEqual(e.voidWonderCost(VoidWonderCatalog.seedId), 2)
        XCTAssertTrue(e.buildVoidWonder(id: VoidWonderCatalog.seedId))
        XCTAssertEqual(e.state.voidSparks, 8)
        XCTAssertEqual(e.voidWonderCost(VoidWonderCatalog.seedId), 4)
        XCTAssertFalse(e.state.builtWonderIds.contains(VoidWonderCatalog.seedId))   // kept out of the shard Wonders' count
        // Prism needs a second multiverse.
        XCTAssertFalse(e.buildVoidWonder(id: VoidWonderCatalog.prismId))

        // Null Seed level 1 keeps 10% of shards through a True Cosmos.
        e.state.cosmicShards = 4e6
        XCTAssertGreaterThan(e.trueCosmos(), 0)
        XCTAssertEqual(e.state.cosmicShards, 4e5)
    }

    func test_nullSeed_capsAtFiftyPercent() {
        var s = GameState()
        s.wonderLevels[VoidWonderCatalog.seedId] = 9
        XCTAssertEqual(s.voidShardCarryFraction, 0.5, accuracy: 1e-12)
    }

    func test_sparkFurnace_doublesBigBangShardsPerLevel() {
        var s = GameState()
        s.lifetimeStardust = 1e12
        s.cosmosCount = 1                     // past Kindling
        let base = engine(s).availableShards
        XCTAssertGreaterThan(base, 0)
        s.wonderLevels[VoidWonderCatalog.furnaceId] = 2
        XCTAssertEqual(engine(s).availableShards, base * 4, accuracy: 4)   // floor() before vs after ×4
    }

    func test_oldSaves_loadWithNoMultiverseFields() throws {
        var json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(GameState())) as! [String: Any]
        for k in ["voidSparks", "lifetimeVoidSparks", "multiverseCount", "lastFreeWarpAt"] { json.removeValue(forKey: k) }
        let old = try JSONDecoder().decode(GameState.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertEqual(old.voidSparks, 0)
        XCTAssertEqual(old.multiverseCount, 0)
        XCTAssertNil(old.lastFreeWarpAt)
    }

    func test_progressRank_aCollapsedSaveBeatsAnUncollapsedOne() {
        var veteran = GameState()
        veteran.lifetimeRealityFragments = 5_000
        var collapsed = GameState()
        collapsed.lifetimeRealityFragments = 4_000
        collapsed.lifetimeVoidSparks = 10
        XCTAssertTrue(collapsed.isAhead(of: veteran))
    }

    // MARK: Premium bundles

    func test_premiumOffer_neverSellsWhatYouOwn() {
        typealias E = IAPManager.Entitlements
        XCTAssertEqual(IAPManager.premiumOffer(E()), .ultimate)
        XCTAssertEqual(IAPManager.premiumOffer(E(removeAds: true, automation: true)), .deluxe)
        XCTAssertEqual(IAPManager.premiumOffer(E(removeAds: true)), .none)
        XCTAssertEqual(IAPManager.premiumOffer(E(removeAds: true, automation: true, doubler: true)), .none)
        XCTAssertEqual(IAPManager.premiumOffer(E(supporter: true)), .none)
        XCTAssertEqual(IAPManager.premiumOffer(E(premium: true)), .none)
    }

    func test_bundles_grantEveryEntitlementTheyName() {
        var u = IAPManager.Entitlements()
        u.grant(IAPManager.ultimateBundleProductId)
        XCTAssertEqual(u, IAPManager.Entitlements(removeAds: true, automation: true, supporter: true, doubler: true, premium: true))
        var d = IAPManager.Entitlements(removeAds: true, automation: true)
        d.grant(IAPManager.deluxeUpgradeProductId)
        XCTAssertEqual(d, IAPManager.Entitlements(removeAds: true, automation: true, supporter: true, doubler: true, premium: true))
        var e = IAPManager.Entitlements()
        e.grant(IAPManager.everythingBundleProductId)
        XCTAssertEqual(e, IAPManager.Entitlements(removeAds: true, automation: true))
    }

    func test_singularityOrb_onlyWithAPremiumBundle() {
        let s = GameState()
        XCTAssertFalse(OrbSkin.singularity.isUnlocked(state: s, supporter: true))
        XCTAssertTrue(OrbSkin.singularity.isUnlocked(state: s, supporter: false, premium: true))
        XCTAssertEqual(OrbSkin.resolve(picked: "singularity", legacyGolden: true, state: s, supporter: true), .tier)
    }

    // MARK: Shard packs

    func test_shardPacks_areThreeAndThirtyBigBangs() {
        var s = GameState()
        s.lastBigBangShards = 1_000
        let e = engine(s)
        let small = GameEngine.smallShardPack, large = GameEngine.largeShardPack
        XCTAssertEqual(e.shardPackAmount(base: small.base, multiple: small.bigBangs), 3_000)
        XCTAssertEqual(e.shardPackAmount(base: large.base, multiple: large.bigBangs), 30_000)
        // Never below the floor for a brand-new player.
        XCTAssertEqual(engine().shardPackAmount(base: small.base, multiple: small.bigBangs), 500)
    }

    func test_shardPackTarget_namesTheBiggestThingNewlyInReach() {
        let e = engine()
        XCTAssertNil(e.shardPackTarget(amount: 0))
        let t = e.shardPackTarget(amount: 1e9)
        XCTAssertNotNil(t)
        XCTAssertLessThanOrEqual(t!.cost, 1e9)
        XCTAssertGreaterThan(t!.cost, 0)
    }

    // MARK: Free daily Time Warp

    func test_freeWarp_oncePerDay_andNotWastedWithNoProduction() {
        let empty = engine()
        XCTAssertEqual(empty.claimFreeWarp(), 0)
        XCTAssertTrue(empty.freeWarpAvailable())      // the day wasn't used up

        var s = GameState()
        s.generators[0].count = 25
        let e = engine(s)
        let rate = e.state.stardustPerSecond
        let now = Date()
        XCTAssertEqual(e.claimFreeWarp(now: now), rate * 1800, accuracy: rate * 1e-6)
        XCTAssertFalse(e.freeWarpAvailable(now: now))
        XCTAssertEqual(e.claimFreeWarp(now: now), 0)
        XCTAssertTrue(e.freeWarpAvailable(now: now.addingTimeInterval(86_400 * 1.5)))
    }

    // MARK: Shop counter

    func test_shopStats_countsPerDay_andStopsWhenOff() {
        let defaults = UserDefaults(suiteName: "V34Tests.shopstats")!
        defaults.removePersistentDomain(forName: "V34Tests.shopstats")
        let stats = ShopStats(defaults: defaults)
        stats.open()
        stats.view("timewarp")
        stats.view("timewarp")
        stats.tap(IAPManager.timeWarp8hProductId)
        stats.buy(IAPManager.timeWarp8hProductId)
        let today = ShopStats.day(Date())
        XCTAssertEqual(stats.counts[today], ["open": 1, "view.timewarp": 2, "tap.timewarp_8h": 1, "buy.timewarp_8h": 1])

        defaults.set(false, forKey: ShopStats.enabledKey)
        stats.clear()
        stats.open()
        XCTAssertTrue(stats.counts.isEmpty)
    }

    func test_shopStats_dropsDaysOlderThanTwoWeeks() {
        let defaults = UserDefaults(suiteName: "V34Tests.prune")!
        defaults.removePersistentDomain(forName: "V34Tests.prune")
        let stats = ShopStats(defaults: defaults)
        let old = Date().addingTimeInterval(-20 * 86_400)
        stats.record("open", now: old)
        stats.record("open")
        stats.prune()
        XCTAssertNil(stats.counts[ShopStats.day(old)])
        XCTAssertEqual(stats.counts[ShopStats.day(Date())]?["open"], 1)
    }
}
