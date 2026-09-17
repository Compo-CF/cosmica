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

    // MARK: - Phase 2: auto-buy step

    /// v3.0 Phase 2 — called from `GameEngine.tickFromTimer` on every tick (10 Hz).
    /// Buys ONE cheapest-eligible generator per call, capped at 50% of current
    /// stardust so the auto-buyer never drains the balance right before a Big Bang.
    /// A no-op when: Automation Core inactive, no candidates, or none affordable
    /// under the cap.
    ///
    /// Eligibility for a generator, all required:
    ///   1. Its previous generator is owned (existing unlock cascade — matches
    ///      `GeneratorRow.unlocked`), OR it's generator 0
    ///   2. Player has toggled auto-buy ON in `state.autoBuyEnabled[gen.id]`
    ///   3. The Autonomy branch on the Cosmic Tree covers this generator's cluster
    ///      per `CosmicTree.isGeneratorAutoBuyUnlocked(index:levels:)`
    func autoBuyStep() {
        guard isActive, let engine else { return }
        let state = engine.state
        let budgetCap = state.stardust * 0.5
        guard budgetCap > 0 else { return }

        // Build the eligible set once, walk once.
        var best: (id: String, cost: Double)?
        for (i, gen) in state.generators.enumerated() {
            // Unlock cascade: gen 0 always unlocked, others need previous owned.
            let unlocked = (i == 0) || (state.generators[i - 1].count >= 1)
            guard unlocked else { continue }
            guard state.autoBuyEnabled[gen.id] == true else { continue }
            guard CosmicTree.isGeneratorAutoBuyUnlocked(
                index: gen.index, levels: state.cosmicSkillLevels
            ) else { continue }
            let cost = gen.nextCost
            guard cost <= budgetCap else { continue }
            if best == nil || cost < best!.cost {
                best = (gen.id, cost)
            }
        }
        if let hit = best {
            _ = engine.buy(generatorId: hit.id, amount: 1)
        }
    }
}
