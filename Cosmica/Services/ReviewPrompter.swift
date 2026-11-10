import SwiftUI
import StoreKit

/// Rate-limited wrapper around `AppStore.requestReview(in:)`. iOS makes the final
/// call and may silently skip; we gate on our side so the few asks Apple allows
/// land on players who already like the game, at a moment that shows it.
///
/// v4.0 rules (planning/v4.0-plan.md, phase 5). Before 4.0 the first ask usually
/// came in the first session (achievement #5, or the first Big Bang worth 10
/// shards) and every app update re-armed it, on the mistaken belief that Apple
/// resets its own budget per version. It doesn't: iOS shows the prompt at most
/// 3 times in 365 days per app, whatever the version.
///   • only invested players: ≥ 2 days since install and ≥ 3 Big Bangs
///   • only big moments: a Big Bang, a Wonder, Absolute, a True Cosmos, a purchase
///   • ≤ 3 asks in any 365 days, ≥ 90 days apart, no reset on update
///   • every ask is counted in ShopStats as `review.ask.<reason>`
@MainActor
@Observable
final class ReviewPrompter {
    static let minDaysInstalled: Double = 2
    static let minBigBangs = 3
    static let maxAsksPerYear = 3
    static let minDaysBetween: Double = 90

    /// When we asked, as comma-separated Unix timestamps (newest last).
    @ObservationIgnored @AppStorage("review.askDates") private var askDatesRaw: String = ""
    /// Pre-4.0 key, read once so an ask made under the old rules still counts.
    @ObservationIgnored @AppStorage("review.lastPromptedAt") private var legacyLastPromptedRaw: Double = 0

    private var askDates: [Date] {
        get {
            var dates = askDatesRaw.split(separator: ",").compactMap { Double($0) }.map(Date.init(timeIntervalSince1970:))
            if dates.isEmpty, legacyLastPromptedRaw > 0 {
                dates = [Date(timeIntervalSince1970: legacyLastPromptedRaw)]
            }
            return dates
        }
        set {
            askDatesRaw = newValue.map { String(Int($0.timeIntervalSince1970)) }.joined(separator: ",")
        }
    }

    /// Pure rule, unit-tested in `V40Tests`.
    static func isEligible(now: Date, installedAt: Date, bigBangs: Int, previousAsks: [Date]) -> Bool {
        let day: TimeInterval = 86_400
        guard now.timeIntervalSince(installedAt) >= minDaysInstalled * day else { return false }
        guard bigBangs >= minBigBangs else { return false }
        let lastYear = previousAsks.filter { now.timeIntervalSince($0) < 365 * day }
        guard lastYear.count < maxAsksPerYear else { return false }
        if let last = previousAsks.max(), now.timeIntervalSince(last) < minDaysBetween * day { return false }
        return true
    }

    /// Ask iOS to consider showing the review prompt. Cheap to call; returns at
    /// once whether or not the sheet appears. `reason` names the moment (counted).
    func maybePrompt(reason: String, state: GameState) {
        let now = Date()
        let previous = askDates
        guard Self.isEligible(now: now, installedAt: state.firstLaunch,
                              bigBangs: state.totalBigBangs, previousAsks: previous) else { return }
        // Idle games are single-window; the first foreground-active scene is right.
        guard let scene = UIApplication.shared.connectedScenes
            .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene else { return }
        AppStore.requestReview(in: scene)
        // Recorded even when iOS suppresses the sheet, so we never spam the call.
        askDates = Array((previous + [now]).suffix(10))
        ShopStats.shared.record("review.ask.\(ShopStats.key(reason))")
    }
}
