import Foundation
import Observation

/// The single source of truth for the running game.
/// Drives a 10Hz tick that accrues stardust based on `state.stardustPerSecond`,
/// handles purchases, prestige, and saves to disk on every meaningful mutation.
@MainActor
@Observable
final class GameEngine {
    var state: GameState
    private let persistence: Persistence
    private var timer: Timer?
    private var lastTickAt: Date = Date()

    /// 10Hz — smooth enough for counters, cheap enough to be invisible on battery.
    private let tickHz: Double = 10.0

    init(state: GameState, persistence: Persistence) {
        self.state = state
        self.persistence = persistence
    }

    // MARK: - Loop

    func start() {
        timer?.invalidate()
        lastTickAt = Date()
        let interval = 1.0 / tickHz
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tickFromTimer() }
        }
        // Tolerance lets iOS coalesce timers and saves a meaningful bit of battery.
        timer?.tolerance = interval * 0.5
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func tickFromTimer() {
        let now = Date()
        let dt = now.timeIntervalSince(lastTickAt)
        lastTickAt = now
        guard dt > 0 else { return }
        let earned = state.stardustPerSecond * dt
        state.stardust += earned
        state.lifetimeStardust += earned
    }

    // MARK: - Manual tap

    @discardableResult
    func manualTap() -> Double {
        let v = state.tapValue
        state.stardust += v
        state.lifetimeStardust += v
        state.totalTaps += 1
        return v
    }

    // MARK: - Purchases

    @discardableResult
    func buy(generatorId: String, amount: Int = 1) -> Bool {
        guard amount > 0,
              let idx = state.generators.firstIndex(where: { $0.id == generatorId })
        else { return false }
        let gen = state.generators[idx]
        let total = gen.bulkCost(amount: amount)
        guard state.stardust >= total else { return false }
        state.stardust -= total
        state.generators[idx].count += amount
        save()
        return true
    }

    @discardableResult
    func buyMaxAffordable(generatorId: String) -> Int {
        guard let idx = state.generators.firstIndex(where: { $0.id == generatorId })
        else { return 0 }
        let gen = state.generators[idx]
        let n = gen.maxAffordable(budget: state.stardust)
        guard n > 0 else { return 0 }
        _ = buy(generatorId: generatorId, amount: n)
        return n
    }

    @discardableResult
    func buyUpgrade(id: String) -> Bool {
        guard let idx = state.upgrades.firstIndex(where: { $0.id == id }) else { return false }
        let up = state.upgrades[idx]
        guard !up.purchased,
              up.isUnlocked(generators: state.generators),
              state.stardust >= up.cost
        else { return false }
        state.stardust -= up.cost
        state.upgrades[idx].purchased = true
        save()
        return true
    }

    // MARK: - Prestige

    var availableShards: Int {
        PrestigeCalculator.shardsEarned(lifetimeStardust: state.lifetimeStardust)
    }

    var canPrestige: Bool { availableShards > 0 }

    @discardableResult
    func bigBang() -> Int {
        let shards = availableShards
        guard shards > 0 else { return 0 }
        state.cosmicShards += Double(shards)
        state.prestigeCount += 1
        state.stardust = 0
        state.lifetimeStardust = 0
        // Reset content but preserve identity ordering
        state.generators = GameContent.defaultGenerators
        state.upgrades = GameContent.defaultUpgrades
        state.lastSeen = Date()
        save()
        return shards
    }

    // MARK: - Boosts

    /// Extend the 2× boost. If a boost is already active, the new duration stacks
    /// on top of the current expiry instead of overwriting it.
    func grantBoost(duration: TimeInterval) {
        let base = max(Date(), state.adBoostExpiresAt ?? .distantPast)
        state.adBoostExpiresAt = base.addingTimeInterval(duration)
        save()
    }

    /// Back-compat shim for the rewarded-ad call site. New code should use `grantBoost(duration:)`.
    func grantAdBoost(duration: TimeInterval = 3600) {
        grantBoost(duration: duration)
    }

    /// Direct grant of Cosmic Shards (paid IAP). Each shard contributes 2% permanent earnings.
    func grantShards(_ amount: Int) {
        state.cosmicShards += Double(amount)
        save()
    }

    /// Offline catch-up with an explicit cap (paid IAPs can pay for longer windows).
    @discardableResult
    func applyOfflineCatchUp(cap: TimeInterval) -> OfflineAccrual.Result {
        let secs = max(0, Date().timeIntervalSince(state.lastSeen))
        let counted = min(secs, cap)
        let earned = state.stardustPerSecond * counted * OfflineAccrual.offlineRate
        state.stardust += earned
        state.lifetimeStardust += earned
        state.lastSeen = Date()
        save()
        return OfflineAccrual.Result(
            stardustEarned: earned,
            secondsElapsed: secs,
            secondsCounted: counted,
            capUsed: cap,
            wasCapped: secs > cap
        )
    }

    // MARK: - Offline accrual

    @discardableResult
    func applyOffline(extended: Bool = false) -> OfflineAccrual.Result {
        let result = OfflineAccrual.compute(
            now: Date(),
            lastSeen: state.lastSeen,
            ratePerSecond: state.stardustPerSecond,
            extended: extended
        )
        state.stardust += result.stardustEarned
        state.lifetimeStardust += result.stardustEarned
        state.lastSeen = Date()
        save()
        return result
    }

    // MARK: - Persistence

    func save() {
        state.lastSeen = Date()
        try? persistence.save(state: state)
    }
}
