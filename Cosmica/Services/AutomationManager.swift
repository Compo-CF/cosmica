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

    // MARK: - Phase 3: auto-Big-Bang step

    /// Auto-fire cadence limit. 30s is generous — a legitimate player can't Big
    /// Bang faster than this anyway, so it never blocks manual play. The cap is
    /// insurance against a coding bug that would otherwise auto-fire every tick.
    private let autoBigBangMinInterval: TimeInterval = 30

    /// v3.0 Phase 3 — called from `GameEngine.tickFromTimer` after auto-buy.
    /// Fires `engine.autoBigBang()` when the shard reward crosses the player's
    /// chosen threshold. Rate-limited to at most one fire per 30 seconds.
    /// No-op when: Automation Core inactive, player hasn't enabled auto-BB,
    /// threshold not met, or cooldown still active.
    func autoBigBangStep() {
        guard isActive, let engine else { return }
        guard engine.state.autoBigBangEnabled else { return }
        guard engine.canPrestige else { return }
        // engine.availableShards is Double post-v2.1.1 — direct comparison.
        guard engine.availableShards >= engine.state.autoBigBangThreshold else { return }
        if let last = engine.state.lastAutoBangAt,
           Date().timeIntervalSince(last) < autoBigBangMinInterval {
            return
        }
        _ = engine.autoBigBang()
    }

    // MARK: - Phase 4: auto-buy Cosmic Tree upgrades

    /// Reserve the player keeps for their own planning. Auto-tree-buy stops
    /// before dipping below this. If the player wants to save for a specific
    /// expensive node, having any 100-shard-plus balance triggers "hands off".
    private let autoTreeReserve: Double = 100

    /// v3.0 Phase 4 — spend freshly-earned shards on the tree. Called from
    /// `GameEngine.bigBang()` at the end so it fires after both manual AND
    /// auto Big Bangs.
    ///
    /// Loop rules:
    ///   - Skip the Autonomy branch (autonomy_*). We don't want auto-buy
    ///     buying its own successor nodes with the shards the player is trying
    ///     to save for something they picked.
    ///   - Buy the cheapest node whose cost would keep `cosmicShards` ≥ reserve.
    ///   - Stop when nothing's affordable under the reserve, or when a
    ///     `buyCosmicSkill` returns false (safety net).
    func autoBuyCosmicTreeStep() {
        guard isActive, let engine, engine.state.autoBuyCosmicTreeEnabled else { return }

        var safety = 0
        while safety < 100 {  // hard iteration cap — defense-in-depth
            safety += 1
            let candidates = CosmicTree.skills
                .filter { !$0.id.hasPrefix("autonomy_") }
                .compactMap { skill -> (id: String, cost: Int)? in
                    let lvl = engine.state.cosmicSkillLevels[skill.id] ?? 0
                    guard lvl < skill.maxLevel else { return nil }
                    return (skill.id, skill.cost(atLevel: lvl))
                }
                .filter { engine.state.cosmicShards - Double($0.cost) >= autoTreeReserve }
                .sorted { $0.cost < $1.cost }
            guard let hit = candidates.first else { return }
            guard engine.buyCosmicSkill(hit.id) else { return }
        }
    }
}
