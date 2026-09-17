import Foundation
import Observation

/// v3.0 — thin @Observable service that answers "should automation be running right
/// now?" for the rest of the app to consult on every tick.
///
/// Two orthogonal sources of activation, OR'd together:
///   1. `IAPManager.automationCoreOwned` — the $2.99 non-consumable
///   2. `GameState.automationTrialExpiresAt` — a 4-hour trial from a rewarded ad
///
/// Ownership state lives on `IAPManager` (StoreKit-backed). Trial state lives on
/// `GameState` (persisted through the normal save flow). This service holds no
/// state of its own — it's a computed façade so callers don't need to know which
/// source turned automation on.
///
/// Wired at app-boot in `CosmicaApp` after `iap` and `engine` are constructed.
/// The refs are set once and never rebound (the App holds strong refs via @State).
@MainActor
@Observable
final class AutomationManager {
    /// Set exactly once by `CosmicaApp.body` after the engine + iap services exist.
    /// Not weak: the App's @State holds the strong ref, we just piggyback.
    @ObservationIgnored
    var iap: IAPManager?

    @ObservationIgnored
    var engine: GameEngine?

    /// True when any Automation feature should be running.
    var isActive: Bool {
        (iap?.automationCoreOwned == true) || trialActive
    }

    /// True while the rewarded-ad trial hasn't expired.
    var trialActive: Bool {
        engine?.state.automationTrialActive == true
    }

    /// Seconds remaining on the trial. Zero if no trial or expired.
    var trialRemaining: TimeInterval {
        guard let exp = engine?.state.automationTrialExpiresAt else { return 0 }
        return max(0, exp.timeIntervalSinceNow)
    }

    /// Grant N hours of trial. Extends from `max(now, existingExpiry)` — a second
    /// rewarded ad while a trial is still ticking adds to it instead of resetting.
    /// Delegates to `GameEngine.grantAutomationTrial(hours:)` for persistence.
    func grantTrial(hours: Double) {
        engine?.grantAutomationTrial(hours: hours)
    }
}
