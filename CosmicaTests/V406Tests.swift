import XCTest
@testable import Cosmica

/// v4.0.6 — Black Friday 2026 sale labels. The price itself is scheduled in App Store Connect;
/// these pin when the app is allowed to say "sale".
@MainActor
final class V406Tests: XCTestCase {
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: "V406Tests")
        defaults.removePersistentDomain(forName: "V406Tests")
    }

    private let ultimate = IAPManager.ultimateBundleProductId

    func test_window_isThanksgivingThroughCyberMondayPacific() {
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(identifier: "UTC")!
        XCTAssertEqual(utc.dateComponents([.year, .month, .day, .hour], from: BlackFridaySale.start),
                       DateComponents(year: 2026, month: 11, day: 27, hour: 8))
        XCTAssertEqual(utc.dateComponents([.year, .month, .day, .hour], from: BlackFridaySale.end),
                       DateComponents(year: 2026, month: 12, day: 2, hour: 8))
        XCTAssertFalse(BlackFridaySale.isOpen(BlackFridaySale.start.addingTimeInterval(-1)))
        XCTAssertTrue(BlackFridaySale.isOpen(BlackFridaySale.start))
        XCTAssertTrue(BlackFridaySale.isOpen(BlackFridaySale.end.addingTimeInterval(-1)))
        XCTAssertFalse(BlackFridaySale.isOpen(BlackFridaySale.end))
    }

    func test_onSale_needsTheWindowAndAPrice() {
        let mid = BlackFridaySale.start.addingTimeInterval(3600)
        XCTAssertFalse(BlackFridaySale.onSale(now: mid, price: nil, regular: nil))
        XCTAssertFalse(BlackFridaySale.onSale(now: BlackFridaySale.start.addingTimeInterval(-60), price: 7.99, regular: 12.99))
        XCTAssertFalse(BlackFridaySale.onSale(now: BlackFridaySale.end, price: 7.99, regular: 12.99))
        XCTAssertTrue(BlackFridaySale.onSale(now: mid, price: 7.99, regular: nil))   // fresh install mid-sale
    }

    func test_neverClaimsASaleTheStoreIsNotCharging() {
        let mid = BlackFridaySale.start.addingTimeInterval(3600)
        XCTAssertTrue(BlackFridaySale.onSale(now: mid, price: 7.99, regular: 12.99))
        XCTAssertFalse(BlackFridaySale.onSale(now: mid, price: 12.99, regular: 12.99))  // price change not live here
        XCTAssertFalse(BlackFridaySale.onSale(now: mid, price: 13.99, regular: 12.99))
    }

    func test_remembersThePreSalePrice_neverTheSalePrice() {
        let before = BlackFridaySale.start.addingTimeInterval(-86_400)
        BlackFridaySale.remember(ultimate, price: Decimal(string: "12.99")!, label: "$12.99", now: before, defaults: defaults)
        BlackFridaySale.remember(ultimate, price: Decimal(string: "7.99")!, label: "$7.99", now: BlackFridaySale.start, defaults: defaults)
        let r = BlackFridaySale.regular(ultimate, defaults: defaults)
        XCTAssertEqual(r?.price, Decimal(string: "12.99"))
        XCTAssertEqual(r?.label, "$12.99")
        XCTAssertNil(BlackFridaySale.regular(IAPManager.deluxeUpgradeProductId, defaults: defaults))
    }

    func test_onlyTheBundleThisPlayerCanBuyIsOnSale() {
        XCTAssertEqual(BlackFridaySale.productId(for: .ultimate), IAPManager.ultimateBundleProductId)
        XCTAssertEqual(BlackFridaySale.productId(for: .deluxe), IAPManager.deluxeUpgradeProductId)
        XCTAssertNil(BlackFridaySale.productId(for: .completeSet))
        XCTAssertNil(BlackFridaySale.productId(for: .none))
    }
}
