import XCTest
@testable import Cosmica

final class WidgetSnapshotTests: XCTestCase {

    private func snapshot(savedAt: Date,
                          baseRate: Double = 10,
                          adBoostExpiresAt: Date? = nil,
                          eventMultiplier: Double = 1,
                          eventExpiresAt: Date? = nil,
                          offlineCap: TimeInterval = OfflineAccrual.baseCap,
                          lastDailyClaim: Date? = nil) -> WidgetSnapshot {
        WidgetSnapshot(
            savedAt: savedAt,
            baseRate: baseRate,
            adBoostMultiplier: adBoostExpiresAt == nil ? 1 : 2,
            adBoostExpiresAt: adBoostExpiresAt,
            eventMultiplier: eventMultiplier,
            eventExpiresAt: eventExpiresAt,
            offlineCap: offlineCap,
            cosmicShards: 0,
            prestigeCount: 0,
            cosmosCount: 0,
            tierTitle: "Stargazer",
            tierSymbol: "binoculars",
            lastDailyClaim: lastDailyClaim
        )
    }

    func test_waiting_matchesOfflineAccrual() {
        let saved = Date()
        let s = snapshot(savedAt: saved)
        let later = saved.addingTimeInterval(3600)
        let expected = OfflineAccrual.compute(now: later, lastSeen: saved, ratePerSecond: 10).stardustEarned
        XCTAssertEqual(s.waiting(at: later), expected, accuracy: 1e-6)
        XCTAssertEqual(s.waiting(at: later), 18_000, accuracy: 1e-6)
    }

    func test_waiting_stopsAtCap_includingBonusCap() {
        let saved = Date()
        let s = snapshot(savedAt: saved, offlineCap: 10 * 3600)   // 8h + 2h Nightwatch
        let wayLater = saved.addingTimeInterval(48 * 3600)
        XCTAssertEqual(s.waiting(at: wayLater), 10 * 3600 * 10 * 0.5, accuracy: 1e-6)
        XCTAssertTrue(s.isFull(at: wayLater))
        XCTAssertEqual(s.fillFraction(at: wayLater), 1)
    }

    func test_expiredBoost_dropsOutOfRate() {
        let saved = Date()
        let s = snapshot(savedAt: saved, adBoostExpiresAt: saved.addingTimeInterval(1800))
        XCTAssertEqual(s.rate(at: saved.addingTimeInterval(600)), 20)
        XCTAssertEqual(s.rate(at: saved.addingTimeInterval(3600)), 10)
    }

    func test_initFromState_dividesOutTransientBoosts() {
        var state = GameState()
        state.generators[0].count = 25
        state.adBoostExpiresAt = Date().addingTimeInterval(3600)
        let boosted = state.stardustPerSecond
        XCTAssertGreaterThan(boosted, 0)
        let snap = WidgetSnapshot(state: state)
        XCTAssertEqual(snap.rate(at: Date()), boosted, accuracy: boosted * 1e-9)
        XCTAssertEqual(snap.rate(at: Date().addingTimeInterval(7200)), boosted / 2, accuracy: boosted * 1e-9)
    }

    func test_timelineDates_stepUntilFull_thenKeyMoments() {
        let now = Date()
        let s = snapshot(savedAt: now.addingTimeInterval(-7 * 3600))   // fills in 1h
        let dates = s.timelineDates(from: now)
        XCTAssertEqual(dates.first, now)
        XCTAssertTrue(dates.contains(s.fullAt))
        XCTAssertEqual(dates, dates.sorted())
        // ~6 steps in the hour before full, plus fullAt and midnight — never a full day of steps.
        XCTAssertLessThan(dates.count, 12)
    }

    func test_dailyRewardReady_flipsOnNewDay() {
        let cal = Calendar(identifier: .gregorian)
        let claim = cal.date(from: DateComponents(year: 2026, month: 9, day: 24, hour: 9))!
        let s = snapshot(savedAt: claim, lastDailyClaim: claim)
        XCTAssertFalse(s.dailyRewardReady(at: claim.addingTimeInterval(3600), calendar: cal))
        XCTAssertTrue(s.dailyRewardReady(at: claim.addingTimeInterval(20 * 3600), calendar: cal))
    }

    func test_roundTripsThroughDefaults() {
        let defaults = UserDefaults(suiteName: "WidgetSnapshotTests")!
        defaults.removePersistentDomain(forName: "WidgetSnapshotTests")
        let s = snapshot(savedAt: Date(timeIntervalSince1970: 1_800_000_000))
        s.save(to: defaults)
        XCTAssertEqual(WidgetSnapshot.load(from: defaults), s)
    }
}
