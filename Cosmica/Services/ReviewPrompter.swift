import SwiftUI
import StoreKit

/// Rate-limited wrapper around `AppStore.requestReview(in:)`. Callers fire this at
/// genuinely happy moments (first Big Bang with a real shard reward, Absolute
/// Ascension, building a Cosmic Wonder). We gate on our own side so we never
/// nag — iOS makes the final decision and may silently skip.
///
/// Apple's own hard limit is 3 prompts per 365 days per app version; we respect
/// it and add a 60-day floor between our own attempts, so version-bump releases
/// like v2.0 refresh the prompt budget cleanly.
@MainActor
@Observable
final class ReviewPrompter {
    @ObservationIgnored @AppStorage("review.lastPromptedAt")  private var lastPromptedRaw: Double = 0
    @ObservationIgnored @AppStorage("review.promptCount")     private var promptCount: Int = 0
    @ObservationIgnored @AppStorage("review.promptedVersion") private var promptedVersion: String = ""

    /// Minimum days between our own prompts. Apple additionally rate-limits system-wide.
    private let minDaysBetween: Double = 60

    private var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
    }

    private var eligible: Bool {
        // Version bump resets our counter — Apple resets its own 3-per-year budget
        // on version change too, so the two stay aligned.
        if promptedVersion != currentVersion { return true }
        let last = Date(timeIntervalSince1970: lastPromptedRaw)
        return Date().timeIntervalSince(last) > minDaysBetween * 86_400
    }

    /// Ask iOS to consider showing the review prompt. Cheap to call from anywhere
    /// on the main actor; returns immediately whether or not the sheet appears.
    /// `reason` is kept for future analytics — currently unused.
    func maybePrompt(reason: String = "") {
        guard eligible else { return }

        // Grab the active scene. Idle games are single-window; the first
        // foreground-active window scene is always the right one.
        if let scene = UIApplication.shared.connectedScenes
            .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
            AppStore.requestReview(in: scene)
        }

        // Record even when iOS may silently suppress — we don't want to spam
        // the requestReview call itself. Reset our count when the version changes.
        if promptedVersion != currentVersion {
            promptCount = 0
            promptedVersion = currentVersion
        }
        promptCount += 1
        lastPromptedRaw = Date().timeIntervalSince1970
    }
}
