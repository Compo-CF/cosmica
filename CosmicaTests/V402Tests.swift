import XCTest
@testable import Cosmica

/// v4.0.2 — offline earnings said "away 0s" (App Store review, 13 Nov 2026). Any save()
/// between launch and applyOffline() moved `lastSeen` to now, and a warm resume never
/// paid the absence at all.
@MainActor
final class V402Tests: XCTestCase {
    private func engine(_ state: GameState) -> GameEngine {
        GameEngine(state: state, persistence: Persistence.inMemory())
    }

    private func away(hours: Double) -> GameState {
        var s = GameState()
        s.generators[0].count = 50
        s.lastSeen = Date().addingTimeInterval(-hours * 3600)
        return s
    }

    func test_aSaveBeforeTheOfflinePayout_keepsTheAbsence() {
        let e = engine(away(hours: 2))
        XCTAssertTrue(e.offlinePending)
        e.save()   // e.g. the Doubler entitlement landing during iap.start()
        let r = e.applyOffline()
        XCTAssertEqual(r.secondsElapsed, 2 * 3600, accuracy: 5)
        XCTAssertGreaterThan(r.stardustEarned, 0)
        XCTAssertFalse(e.offlinePending)
    }

    func test_afterThePayout_savesStampLastSeenAgain() {
        let e = engine(away(hours: 2))
        e.applyOffline()
        e.state.lastSeen = Date().addingTimeInterval(-600)
        e.save()
        XCTAssertEqual(e.state.lastSeen.timeIntervalSinceNow, 0, accuracy: 5)
    }

    func test_backgrounding_stampsNow_thenAWarmResumePaysTheTimeAway() {
        let e = engine(away(hours: 0))
        e.applyOffline()
        e.enterBackground()
        XCTAssertTrue(e.offlinePending)
        XCTAssertEqual(e.state.lastSeen.timeIntervalSinceNow, 0, accuracy: 5)

        // Three hours pass while the app sits suspended; a save on the way back in
        // must not swallow them.
        e.state.lastSeen = Date().addingTimeInterval(-3 * 3600)
        e.save()
        let r = e.applyOffline()
        XCTAssertEqual(r.secondsElapsed, 3 * 3600, accuracy: 5)
        XCTAssertGreaterThan(r.stardustEarned, 0)
        XCTAssertFalse(e.offlinePending)
    }

    func test_adoptingACloudSave_paysFromThatSavesLastSeen() {
        let e = engine(away(hours: 0))
        e.applyOffline()
        e.state = away(hours: 5)   // CosmicaApp.syncFromCloud: the iCloud save is ahead
        let r = e.applyOffline()
        XCTAssertEqual(r.secondsElapsed, 5 * 3600, accuracy: 5)
        XCTAssertEqual(r.secondsCounted, 5 * 3600, accuracy: 5)   // under the 8h base cap
        XCTAssertGreaterThan(r.stardustEarned, 0)
    }
}
