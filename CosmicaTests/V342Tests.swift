import XCTest
@testable import Cosmica

/// v3.4.2 — Complete Your Set: players who own some permanent pieces but fit
/// neither premium bundle (e.g. Automation Core alone) saw no bundle card.
@MainActor
final class V342Tests: XCTestCase {
    typealias E = IAPManager.Entitlements

    func test_missingPieces_listOnlyWhatIsNotOwned_inShopOrder() {
        XCTAssertEqual(IAPManager.missingSetPieces(E(automation: true)), [
            IAPManager.removeAdsProductId, IAPManager.stardustDoublerProductId, IAPManager.supporterProductId,
        ])
        XCTAssertEqual(IAPManager.missingSetPieces(E(removeAds: true, automation: true, doubler: true)),
                       [IAPManager.supporterProductId])
        XCTAssertTrue(IAPManager.missingSetPieces(E(removeAds: true, automation: true, supporter: true, doubler: true)).isEmpty)
    }

    func test_deluxeHint_onlyWhenOnePieceOpensIt() {
        XCTAssertEqual(IAPManager.deluxeUnlockedBy(E(automation: true)), IAPManager.removeAdsProductId)
        XCTAssertEqual(IAPManager.deluxeUnlockedBy(E(removeAds: true)), IAPManager.automationCoreProductId)
        XCTAssertNil(IAPManager.deluxeUnlockedBy(E()))                                        // Ultimate's case
        XCTAssertNil(IAPManager.deluxeUnlockedBy(E(removeAds: true, automation: true)))       // already Deluxe
        XCTAssertNil(IAPManager.deluxeUnlockedBy(E(automation: true, doubler: true)))         // Deluxe would re-sell the Doubler
        XCTAssertNil(IAPManager.deluxeUnlockedBy(E(automation: true, premium: true)))
    }

    // v3.4.3 — no duplicate Remove Ads card while the set card lists it.
    func test_standaloneRemoveAds_hiddenOnlyWhileSetCardSellsIt() {
        let automationOnly = E(automation: true)
        XCTAssertFalse(IAPManager.showsStandaloneRemoveAds(automationOnly, removeAdsLoaded: true))
        XCTAssertTrue(IAPManager.showsStandaloneRemoveAds(automationOnly, removeAdsLoaded: false)) // set card has no row yet
        XCTAssertTrue(IAPManager.showsStandaloneRemoveAds(E(), removeAdsLoaded: true))             // Ultimate: no set card
        XCTAssertTrue(IAPManager.showsStandaloneRemoveAds(E(removeAds: true, doubler: true), removeAdsLoaded: true)) // owned: thanks state
        XCTAssertTrue(IAPManager.showsStandaloneRemoveAds(E(removeAds: true, automation: true), removeAdsLoaded: true)) // Deluxe
    }

    func test_everyOwnershipMix_getsExactlyOneOffer_andNeverResellsAPiece() {
        for mask in 0..<16 {
            let e = E(removeAds: mask & 1 != 0, automation: mask & 2 != 0,
                      supporter: mask & 4 != 0, doubler: mask & 8 != 0)
            let offer = IAPManager.premiumOffer(e)
            if mask == 15 {
                XCTAssertEqual(offer, .none, "everything owned")
            } else {
                XCTAssertNotEqual(offer, .none, "mask \(mask) had nothing to buy")
            }
            if offer == .completeSet {
                for id in IAPManager.missingSetPieces(e) {
                    var after = e
                    after.grant(id)
                    XCTAssertNotEqual(after, e, "\(id) was already owned (mask \(mask))")
                }
            }
        }
    }
}
