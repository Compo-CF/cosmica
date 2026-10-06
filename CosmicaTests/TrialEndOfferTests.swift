import XCTest
@testable import Cosmica

final class TrialEndOfferTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func show(expiry: Date?, owned: Bool = false,
                      offered: Date? = nil, shown: Date? = nil) -> Bool {
        TrialEndOffer.shouldShow(trialExpiresAt: expiry, automationOwned: owned,
                                 lastOfferedExpiry: offered, lastShownAt: shown, now: now)
    }

    func test_showsRightAfterATrialEnds() {
        XCTAssertTrue(show(expiry: now.addingTimeInterval(-60)))
    }

    func test_notWhileTrialRunning_orWithoutOne() {
        XCTAssertFalse(show(expiry: now.addingTimeInterval(600)))
        XCTAssertFalse(show(expiry: nil))
    }

    func test_notForOwners() {
        XCTAssertFalse(show(expiry: now.addingTimeInterval(-60), owned: true))
    }

    func test_notForStaleTrials() {
        XCTAssertFalse(show(expiry: now.addingTimeInterval(-(TrialEndOffer.staleAfter + 60))))
    }

    func test_oncePerTrial() {
        let expiry = now.addingTimeInterval(-60)
        XCTAssertFalse(show(expiry: expiry, offered: expiry, shown: now.addingTimeInterval(-2 * 86_400)))
    }

    func test_newTrial_waitsOutTheDailyGap() {
        let expiry = now.addingTimeInterval(-60)
        let oldExpiry = now.addingTimeInterval(-30 * 3600)
        XCTAssertFalse(show(expiry: expiry, offered: oldExpiry, shown: now.addingTimeInterval(-3600)))
        XCTAssertTrue(show(expiry: expiry, offered: oldExpiry, shown: now.addingTimeInterval(-25 * 3600)))
    }

    func test_recordShown_roundTrips() {
        let d = UserDefaults(suiteName: "TrialEndOfferTests")!
        d.removePersistentDomain(forName: "TrialEndOfferTests")
        let expiry = now.addingTimeInterval(-60)
        TrialEndOffer.recordShown(forExpiry: expiry, at: now, d)
        XCTAssertEqual(TrialEndOffer.lastOfferedExpiry(d), expiry)
        XCTAssertEqual(TrialEndOffer.lastShownAt(d), now)
    }
}
