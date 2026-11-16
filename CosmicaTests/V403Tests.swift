import XCTest
@testable import Cosmica

/// v4.0.3 — the rewarded-ad boost banks at most 8h. On 15 Nov 2026 one device watched
/// 208 rewarded ads (207 Shop boosts) because every ad stacked another hour forever.
@MainActor
final class V403Tests: XCTestCase {
    private func engine() -> GameEngine {
        GameEngine(state: GameState(), persistence: Persistence.inMemory())
    }

    private func left(_ e: GameEngine, at now: Date) -> TimeInterval {
        (e.state.adBoostExpiresAt ?? now).timeIntervalSince(now)
    }

    func test_oneAd_addsOneGrant() {
        let e = engine(), now = Date()
        XCTAssertFalse(e.adBoostFull(now: now))
        e.grantAdBoost(now: now)
        XCTAssertEqual(left(e, at: now), e.adBoostGrant, accuracy: 1)
    }

    func test_adsStack_untilTheBankIsFull_thenStop() {
        let e = engine(), now = Date()
        let fits = Int(GameEngine.adBoostBankCap / e.adBoostGrant)
        for _ in 0..<fits { e.grantAdBoost(now: now) }
        XCTAssertEqual(left(e, at: now), Double(fits) * e.adBoostGrant, accuracy: 1)
        XCTAssertTrue(e.adBoostFull(now: now))
        for _ in 0..<200 { e.grantAdBoost(now: now) }   // the 15 Nov device
        XCTAssertLessThanOrEqual(left(e, at: now), GameEngine.adBoostBankCap + 1)
    }

    func test_bankDrains_andTheButtonComesBack() {
        let e = engine(), now = Date()
        for _ in 0..<20 { e.grantAdBoost(now: now) }
        XCTAssertTrue(e.adBoostFull(now: now))
        XCTAssertFalse(e.adBoostFull(now: now.addingTimeInterval(e.adBoostGrant + 60)))
    }

    // MARK: Shards Huge

    private func packs(_ e: GameEngine) -> [Big] {
        [GameEngine.smallShardPack, GameEngine.largeShardPack, GameEngine.hugeShardPack]
            .map { e.shardPackAmount(base: $0.base, multiple: $0.bigBangs) }
    }

    func test_shardPacks_growSmallLargeHuge_atEveryStage() {
        for lastBang in [Big(0), Big(1e6), Big(1e40)] {
            let e = engine()
            e.state.lastBigBangShards = lastBang
            let p = packs(e)
            XCTAssertLessThan(p[0], p[1], "small < large at \(lastBang)")
            XCTAssertLessThan(p[1], p[2], "large < huge at \(lastBang)")
        }
    }

    func test_shardsPerDollar_riseWithEachTier() {
        let e = engine()
        e.state.lastBigBangShards = Big(1e6)
        let p = packs(e), prices = [1.99, 9.99, 19.99]
        let perDollar = zip(p, prices).map { $0.0 / Big($0.1) }
        XCTAssertLessThan(perDollar[0], perDollar[1])
        XCTAssertLessThan(perDollar[1], perDollar[2])
        XCTAssertTrue(IAPManager.consumableIds.contains(IAPManager.shardsHugeProductId))
        XCTAssertTrue(IAPManager.allProductIds.contains(IAPManager.shardsHugeProductId))
    }

    func test_aPaidBoostIsNeverShortened_andReadsAsFull() {
        let e = engine()
        e.grantBoost(duration: 24 * 3600)   // boost_2x_24hr purchase
        let before = e.state.adBoostExpiresAt
        let now = Date()
        XCTAssertTrue(e.adBoostFull(now: now))
        e.grantAdBoost(now: now)
        XCTAssertEqual(e.state.adBoostExpiresAt, before)
    }
}
