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

    func test_formatter_pastDouble() {
        XCTAssertEqual(Formatter.short(Big(1_500)), "1.50K")
        XCTAssertEqual(Formatter.short(Big(mantissa: 4.82, exponent: 71)), "4.82e71")
        XCTAssertEqual(Formatter.short(Big(mantissa: 1.234, exponent: 4_567)), "1.23e4567")
        XCTAssertEqual(Formatter.short(Big(mantissa: 1.234, exponent: 12_345)), "1.23e12,345")
    }
}
