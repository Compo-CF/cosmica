import XCTest
@testable import Cosmica

/// v3.1 — Time Warp and progress-scaled Cosmic Shard packs.
@MainActor
final class MonetizationTests: XCTestCase {
    private func engine(_ state: GameState = GameState()) -> GameEngine {
        GameEngine(state: state, persistence: Persistence.inMemory())
    }

    // 3.3.1 — an unloaded product shows "Loading…", never a made-up US price.
    func test_priceLabel_unloadedProductIsLoadingNotAFakePrice() {
        let iap = IAPManager()
        for id in IAPManager.allProductIds {
            XCTAssertNil(iap.displayPrice(for: id), id)
            XCTAssertEqual(iap.priceLabel(for: id), IAPManager.loadingPriceLabel, id)
        }
    }

    func test_shardPack_neverBelowItsOriginalAmount() {
        let e = engine()
        XCTAssertEqual(e.shardPackAmount(base: 250, multiple: 1), 250)
        XCTAssertEqual(e.shardPackAmount(base: 2500, multiple: 10), 2500)
    }

    func test_shardPack_scalesWithTheLastBigBang() {
        var s = GameState()
        s.lastBigBangShards = 25e12          // the Reddit player's late game
        let e = engine(s)
        XCTAssertEqual(e.shardPackAmount(base: 250, multiple: 1), 25e12)
        XCTAssertEqual(e.shardPackAmount(base: 2500, multiple: 10), 25e13)
    }

    func test_bigBang_recordsItsPayout() {
        var s = GameState()
        s.lifetimeStardust = 1e12            // first cosmos, first Big Bang: 150 ◈, ×3 Kindling
        let e = engine(s)
        let paid = e.bigBang()
        XCTAssertEqual(paid, 450)
        XCTAssertEqual(e.state.lastBigBangShards, 450)
    }

    func test_timeWarp_isHoursOfProductionAtTheFullRate() {
        var s = GameState()
        s.generators[0].count = 25
        let e = engine(s)
        let rate = e.state.stardustPerSecond
        XCTAssertGreaterThan(rate, 0)
        XCTAssertEqual(e.timeWarpAmount(hours: 8), rate * 8 * 3600, accuracy: rate * 1e-6)

        let before = e.state.lifetimeStardust
        let added = e.applyTimeWarp(hours: 8)
        XCTAssertEqual(added, rate * 8 * 3600, accuracy: rate * 1e-6)
        XCTAssertEqual(e.state.lifetimeStardust - before, added, accuracy: added * 1e-9)
    }

    func test_timeWarp_withNoProduction_grantsNothing() {
        let e = engine()
        XCTAssertEqual(e.applyTimeWarp(hours: 24), 0)
    }
}
