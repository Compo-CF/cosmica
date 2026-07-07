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

        // Retire expired events, roll a new one if the cooldown has passed.
        updateCosmicEvent(now: now)

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
        let base = PrestigeCalculator.shardsEarned(lifetimeStardust: state.lifetimeStardust)
        let treeMult = CosmicTree.bigBangYieldMultiplier(state.cosmicSkillLevels)
        let eventMult = CosmicEventScheduler.bigBangYieldMultiplier(state.activeEvent)
        return Int(Double(base) * treeMult * eventMult)
    }

    var canPrestige: Bool { availableShards > 0 }

    @discardableResult
    func bigBang() -> Int {
        let shards = availableShards
        guard shards > 0 else { return 0 }
        state.cosmicShards += Double(shards)
        state.prestigeCount += 1
        state.stardust = CosmicTree.startingStardust(state.cosmicSkillLevels)
        state.lifetimeStardust = 0
        // Reset generators/upgrades (also resets specialization to nil per default).
        state.generators = GameContent.defaultGenerators
        state.upgrades = GameContent.defaultUpgrades
        state.lastSeen = Date()
        save()
        return shards
    }

    // MARK: - Cosmic tree

    func cosmicSkillLevel(_ id: String) -> Int { state.cosmicSkillLevels[id] ?? 0 }

    /// Cosmic-shard cost of the next level, or nil if maxed / unknown.
    func cosmicSkillCost(_ id: String) -> Int? {
        guard let skill = CosmicTree.skill(id) else { return nil }
        let lvl = cosmicSkillLevel(id)
        guard lvl < skill.maxLevel else { return nil }
        return skill.cost(atLevel: lvl)
    }

    @discardableResult
    func buyCosmicSkill(_ id: String) -> Bool {
        guard let skill = CosmicTree.skill(id) else { return false }
        let lvl = cosmicSkillLevel(id)
        guard lvl < skill.maxLevel else { return false }
        let cost = skill.cost(atLevel: lvl)
        guard state.cosmicShards >= Double(cost) else { return false }
        state.cosmicShards -= Double(cost)
        state.cosmicSkillLevels[id] = lvl + 1
        save()
        return true
    }

    // MARK: - Generator specialization

    /// Whether the player can commit `generatorId` to a specialization right now.
    func canSpecialize(generatorId: String) -> Bool {
        state.generators.first(where: { $0.id == generatorId })?.isSpecializable ?? false
    }

    /// Commit a generator to a specialization. Permanent until the next Big Bang.
    @discardableResult
    func specialize(generatorId: String, specId: String) -> Bool {
        guard let idx = state.generators.firstIndex(where: { $0.id == generatorId }) else { return false }
        guard state.generators[idx].isSpecializable else { return false }
        guard GeneratorSpecCatalog.spec(id: specId) != nil else { return false }
        state.generators[idx].specialization = specId
        save()
        return true
    }

    // MARK: - Daily rewards

    var dailyRewardAvailable: Bool {
        guard let last = state.lastDailyClaim else { return true }
        return !Calendar.current.isDate(last, inSameDayAs: Date())
    }

    private func nextDailyStreak() -> Int {
        guard let last = state.lastDailyClaim else { return 1 }
        let cal = Calendar.current
        let days = cal.dateComponents([.day], from: cal.startOfDay(for: last), to: cal.startOfDay(for: Date())).day ?? 99
        if days <= 0 { return max(1, state.dailyStreak) }
        return days == 1 ? state.dailyStreak + 1 : 1
    }

    private func dailyStardust(_ mult: Double) -> Double {
        max(500, state.stardustPerSecond * 1800 * mult)
    }

    private func reward(forStreak streak: Int) -> DailyReward {
        let day = ((streak - 1) % 7) + 1
        var stardust = 0.0, shards = 0, boostHours = 0.0
        switch day {
        case 1: stardust = dailyStardust(1)
        case 2: shards = 1
        case 3: boostHours = 1
        case 4: stardust = dailyStardust(2)
        case 5: shards = 2
        case 6: boostHours = 2
        default: shards = 3; stardust = dailyStardust(3)
        }
        return DailyReward(day: day, streak: streak, stardust: stardust, cosmicShards: shards, boostHours: boostHours)
    }

    /// What claiming right now would grant (for the sheet preview).
    func previewDailyReward() -> DailyReward { reward(forStreak: nextDailyStreak()) }

    @discardableResult
    func claimDaily() -> DailyReward {
        let streak = nextDailyStreak()
        let r = reward(forStreak: streak)
        state.stardust += r.stardust
        state.lifetimeStardust += r.stardust
        state.cosmicShards += Double(r.cosmicShards) * CosmicEventScheduler.shardGrantMultiplier(state.activeEvent)
        state.dailyStreak = streak
        state.lastDailyClaim = Date()
        if r.boostHours > 0 { grantBoost(duration: r.boostHours * 3600) } // grantBoost saves
        else { save() }
        return r
    }

    // MARK: - Cosmic Events (timed buff windows)

    /// End-expired-events, and roll a new one when the cooldown has passed.
    /// Called from the tick so state stays fresh without a dedicated timer.
    private func updateCosmicEvent(now: Date) {
        if let exp = state.activeEventExpiresAt, now >= exp {
            state.activeEventId = nil
            state.activeEventExpiresAt = nil
            state.lastEventEndedAt = exp
        }
        guard state.activeEventId == nil else { return }
        guard CosmicEventScheduler.canRoll(now: now, lastEventEnd: state.lastEventEndedAt) else { return }
        // Simple: once past cooldown, roll deterministically from `now`.
        let event = CosmicEventScheduler.rollEvent(now: now)
        state.activeEventId = event.id
        state.activeEventExpiresAt = now.addingTimeInterval(event.duration)
    }

    /// Force a new event to fire — useful for a Debug menu button.
    func triggerEventNow() {
        let event = CosmicEventScheduler.rollEvent(now: Date())
        state.activeEventId = event.id
        state.activeEventExpiresAt = Date().addingTimeInterval(event.duration)
        save()
    }

    // MARK: - Boosts

    /// Extend the 2× boost. If a boost is already active, the new duration stacks
    /// on top of the current expiry instead of overwriting it. Cosmic-tree "Boost
    /// Extension" adds a flat bonus to every extension.
    func grantBoost(duration: TimeInterval) {
        let bonus = CosmicTree.boostExtensionSeconds(state.cosmicSkillLevels)
        let base = max(Date(), state.adBoostExpiresAt ?? .distantPast)
        state.adBoostExpiresAt = base.addingTimeInterval(duration + bonus)
        save()
    }

    /// Back-compat shim for the rewarded-ad call site. New code should use `grantBoost(duration:)`.
    func grantAdBoost(duration: TimeInterval = 3600) {
        grantBoost(duration: duration)
    }

    /// Direct grant of Cosmic Shards (paid IAP, daily reward, cosmic event).
    /// Applies the active-event shard multiplier if any.
    func grantShards(_ amount: Int) {
        let mult = CosmicEventScheduler.shardGrantMultiplier(state.activeEvent)
        state.cosmicShards += Double(amount) * mult
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
            extended: extended,
            extraCap: CosmicTree.offlineCapBonus(state.cosmicSkillLevels)
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
