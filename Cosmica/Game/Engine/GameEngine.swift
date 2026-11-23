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

    /// v3.0: back-reference to the Automation service so `tickFromTimer` can run
    /// its auto-buy step in-line with the earnings tick. Weak so we don't cycle
    /// with `AutomationManager.engine` (strong the other direction). Set once at
    /// app-boot by CosmicaApp; nil until then.
    @ObservationIgnored
    weak var automation: AutomationManager?

    /// Transient flag flipped when the player first crosses Absolute. Observed by RootView
    /// to present the celebration sheet. Consumed via `acknowledgeAscension()` which
    /// persists `absoluteCelebrationShown` so the sheet never re-fires.
    private(set) var showAbsoluteCelebration: Bool = false
    /// One-time reward granted with the Absolute Ascension.
    static let absoluteAscensionShardBonus: Int = 500

    init(state: GameState, persistence: Persistence) {
        self.state = state
        self.persistence = persistence
    }

    // MARK: - Loop

    func start() {
        timer?.invalidate()
        lastTickAt = Date()
        refreshChallenge(now: lastTickAt)
        refreshTrail(now: lastTickAt)
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
        // v3.2 — start the new week's challenge if the week turned over.
        refreshChallenge(now: now)
        // v4.0.4/4.0.5 — Seasonal Trails: start one inside its window, settle it after.
        refreshTrail(now: now)

        addStardust(state.stardustPerSecond * dt)

        checkAbsoluteAscension()
        checkAchievements()
        checkChallenge()

        // v3.0 Phase 2 — cheap no-op when automation is off. When on, spends up to
        // half the current budget on the cheapest eligible generator on this tick.
        automation?.autoBuyStep()
        // v3.0 Phase 3 — auto-Big-Bang when threshold crossed. Rate-limited to
        // at most one fire per 30 seconds via `state.lastAutoBangAt`.
        automation?.autoBigBangStep()
        // v4.0 — Omniverse autopilots (earned with Echoes, separate from Automation Core).
        omniverseAutomationStep(now: now)
    }

    // MARK: - Achievements (v2.0)

    /// Transient list of achievements newly unlocked on the last check. AchievementsView
    /// doesn't consume it (yet), but a future "toast" UI can read + clear.
    private(set) var recentAchievementUnlocks: [Achievement] = []

    /// Fold every newly-met achievement into `unlockedAchievementIds` and, when at least
    /// one flipped, save. Cheap enough to run every tick — 25 catalog entries × constant
    /// arithmetic each.
    private func checkAchievements() {
        let unlocked = state.unlockedAchievementIds
        let newly = AchievementCatalog.newlyMet(state: state, unlocked: unlocked)
        guard !newly.isEmpty else { return }
        for a in newly {
            state.unlockedAchievementIds.insert(a.id)
        }
        recentAchievementUnlocks.append(contentsOf: newly)
        save()
    }

    // MARK: - Absolute Ascension (v1.3)

    /// If the player has just crossed the Absolute threshold for the very first time,
    /// stamp the ascension date, grant the one-time shard bonus, and queue the
    /// celebration sheet. Called from every tick + after any offline accrual.
    private func checkAbsoluteAscension() {
        checkOmniverseDoor()   // v4.0 — every path that adds Stardust comes through here
        guard state.absoluteAscendedAt == nil else { return }
        guard state.lifetimeStardust >= Tier.absolute.threshold else { return }
        state.absoluteAscendedAt = Date()
        state.cosmicShards += Double(Self.absoluteAscensionShardBonus)
        state.lifetimeCosmicShards += Double(Self.absoluteAscensionShardBonus)
        showAbsoluteCelebration = true
        save()
    }

    /// Called by the celebration sheet on dismiss. Persists the "already shown" flag
    /// so it never re-fires — the reward is granted at most once per save.
    func acknowledgeAscension() {
        state.absoluteCelebrationShown = true
        showAbsoluteCelebration = false
        save()
    }

    // MARK: - Manual tap

    @discardableResult
    func manualTap() -> Big {
        let v = state.tapValue
        addStardust(v)
        state.totalTaps += 1
        return v
    }

    // MARK: - Number ceiling (v3.2)

    /// Highest value Stardust is allowed to reach. Far beyond any real save, but
    /// short of infinity: once a balance is ∞, costs subtract to ∞ and ∞ × 0 is
    /// NaN, which would freeze the save for good.
    /// Every Stardust gain goes through here (tick, tap, offline, Time Warp,
    /// daily reward). v4.0: no ceiling. `Big` can't become ∞ or NaN (the reason
    /// 3.2 capped at 1e300), and dilation past 1.8e308 (Omniverse.swift) keeps
    /// growth from running away.
    private func addStardust(_ amount: Big) {
        guard amount > 0 else { return }
        state.stardust += amount
        state.lifetimeStardust += amount
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
        state.totalGeneratorsBought += Double(amount)
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

    /// v2.1.1: `Double` (was `Int`). Int64.max pinned rewards at ~9.2e18 for
    /// endgame players past ~3.8e33 lifetime; Double handles up to ~1.7e308.
    /// The .nextDown clamp is gone — it was only there because of the Int
    /// conversion, which no longer happens. Keep isFinite/>0 for defense.
    var availableShards: Big {
        let base: Big = PrestigeCalculator.shardsEarned(lifetimeStardust: state.lifetimeStardust,
                                                        floor: bigBangUnlockAt)
        let treeMult: Big = CosmicTree.bigBangYieldMultiplier(state.cosmicSkillLevels)
        let eventMult: Double = CosmicEventScheduler.bigBangYieldMultiplier(state.activeEvent)
        let wonderMult: Big = state.voidBigBangMultiplier * state.wonderBigBangYieldMultiplier   // v3.4 Spark Furnace
        let raw = PrestigeCalculator.kindled(base * treeMult * wonderMult * eventMult,
                                             lifetimeShards: state.lifetimeCosmicShards,
                                             cosmosCount: state.cosmosCount)
        guard raw > 0 else { return .zero }
        return raw.floored
    }

    /// v3.3 — Big Bangs pay ×3 until the player has earned enough shards for the
    /// whole Cosmic Tree (first cosmos only). See `PrestigeCalculator.kindled`.
    var kindlingActive: Bool {
        PrestigeCalculator.kindlingActive(lifetimeShards: state.lifetimeCosmicShards, cosmosCount: state.cosmosCount)
    }

    var canPrestige: Bool { availableShards > 0 }

    /// v3.0.4 — lifetime stardust this run needs before Big Bang unlocks
    /// (10B / 100B / 1T ramp in the first cosmos; see `PrestigeCalculator.unlockFloor`).
    var bigBangUnlockAt: Double {
        PrestigeCalculator.unlockFloor(prestigeCount: state.prestigeCount, cosmosCount: state.cosmosCount)
    }

    @discardableResult
    func bigBang() -> Big {
        let shards = availableShards
        guard shards > 0 else { return .zero }
        // v3.2 — latch a single-run challenge and record the run before it resets.
        checkChallenge()
        state.bestRunStardust = state.bestRunSoFar
        state.cosmosBestRun = state.cosmosBestSoFar   // v3.4.1 Cosmos Goal
        state.omniverseBestRun = state.omniverseBestSoFar   // v4.0
        state.cosmicShards += shards
        state.lifetimeCosmicShards += shards
        state.prestigeCount += 1
        state.totalBigBangs += 1
        state.lastBigBangShards = shards
        state.stardust = CosmicTree.startingStardust(state.cosmicSkillLevels)
        state.lifetimeStardust = .zero
        // Reset generators/upgrades (also resets specialization to nil per default).
        state.generators = GameContent.defaultGenerators
        state.upgrades = GameContent.defaultUpgrades
        state.lastSeen = Date()
        save()
        // v3.0 Phase 4 — after the shard grant, let auto-tree-buy sweep. No-op
        // when disabled. Runs from both manual and auto Big Bang paths since
        // `autoBigBang()` calls back into this method.
        automation?.autoBuyCosmicTreeStep()
        return shards
    }

    // MARK: - True Cosmos (v1.4 meta-prestige)

    /// Reality Fragments the player would earn if they True Cosmoi'd right now.
    /// Absolute Aperture Wonder adds +25%.
    /// v3.2: `Double` (was `Int`, which trapped past Int64.max — see
    /// `CosmosCalculator.fragmentsEarned`). This is read every time the Big
    /// Bang tab draws, so the old conversion would crash on open, not on tap.
    var availableFragments: Big {
        let base: Big = CosmosCalculator.fragmentsEarned(cosmicShards: state.cosmicShards)
        // v3.4 — unspent Void Sparks and the Fragment Prism multiply it too.
        let rift = pow(RiftCatalog.silentVoidRewardPerTier, Double(state.riftTier(RiftCatalog.silentVoidId)))   // v4.0
        return (base * state.voidFragmentMultiplier * (state.wonderFragmentMultiplier * rift)).floored
    }

    /// True Cosmos unlocks after Absolute Ascension AND when the shard balance yields
    /// at least one Fragment. Both gates are needed — otherwise a first-run player
    /// could Cosmos immediately for zero yield.
    var canTrueCosmos: Bool {
        state.hasAbsoluteAscended && availableFragments > 0 && cosmosGoalMet
    }

    /// v3.4.1 — lifetime Stardust one run in this cosmos must reach first.
    /// v4.0 — counts cosmoi since the last Omniverse collapse (pre-4.0 saves: all of them).
    var cosmosGoal: Big { CosmosCalculator.goal(cosmosCount: state.cosmosSinceOmniverse) }
    var cosmosGoalMet: Bool { state.cosmosBestSoFar >= cosmosGoal }

    /// Collapse the current cosmos into Reality Fragments. Trades every Cosmic Shard,
    /// every tree level, every generator, and every upgrade for a permanent +5% per
    /// Fragment multiplier that stacks across all future Cosmoi. Keeps the Absolute
    /// Observer title.
    @discardableResult
    func trueCosmos() -> Big {
        let fragments = availableFragments
        guard fragments > 0, canTrueCosmos else { return .zero }
        checkChallenge()
        state.bestRunStardust = state.bestRunSoFar
        state.omniverseBestRun = state.omniverseBestSoFar   // v4.0
        state.realityFragments += fragments
        state.lifetimeRealityFragments += fragments
        state.cosmosCount += 1
        state.cosmosSinceOmniverse += 1   // v4.0 — the goal ladder restarts per Omniverse

        // v3.4 Null Seed — a share of the shards survives. Not new earnings,
        // so lifetimeCosmicShards is left alone.
        let carried = (state.cosmicShards * state.voidShardCarryFraction).floored
        resetCosmos()
        if carried > 0 { state.cosmicShards = carried }

        state.lastSeen = Date()
        save()
        return fragments
    }

    /// Everything a True Cosmos (and a Multiverse Collapse) resets: what a Big
    /// Bang resets, plus Cosmic Shards and the tree.
    private func resetCosmos() {
        state.stardust = .zero
        state.lifetimeStardust = .zero
        state.cosmicShards = .zero
        state.prestigeCount = 0
        state.cosmosBestRun = .zero     // v3.4.1 — a new cosmos, a new goal
        state.generators = GameContent.defaultGenerators
        state.upgrades = GameContent.defaultUpgrades
        // v3.0 — Autonomy branch keys survive True Cosmos. Same class of
        // permanent unlock as Cosmic Wonders: the player paid $2.99 for
        // Automation Core (or is trialing it), forcing them to re-buy the
        // auto-buy tier gates every collapse punishes ownership.
        state.cosmicSkillLevels = state.cosmicSkillLevels.filter { $0.key.hasPrefix("autonomy_") }
        // Absolute Observer title survives — they earned it once, they keep it forever.
        // absoluteAscendedAt and absoluteCelebrationShown intentionally NOT reset.
    }

    // MARK: - Multiverse Collapse (v3.4, third prestige layer)

    /// Void Sparks a collapse would pay right now.
    var availableSparks: Big {
        let rift = pow(RiftCatalog.silentVoidRewardPerTier, Double(state.riftTier(RiftCatalog.silentVoidId)))   // v4.0
        return (MultiverseCalculator.sparksEarned(realityFragments: state.realityFragments) * rift).floored
    }

    /// Open once the player has collapsed enough cosmoi; usable once their
    /// fragments would yield at least one spark.
    var multiverseUnlocked: Bool { state.cosmosCount >= MultiverseCalculator.cosmosRequired }
    var canCollapseMultiverse: Bool { multiverseUnlocked && availableSparks > 0 }

    /// Trade every Reality Fragment, and everything a True Cosmos resets, for
    /// Void Sparks. Kept: Wonders (shard and void), achievements, challenge
    /// stars, cosmos count, Absolute, purchases. Returns the sparks earned.
    @discardableResult
    func multiverseCollapse() -> Big {
        let sparks = availableSparks
        guard canCollapseMultiverse, sparks > 0 else { return .zero }
        checkChallenge()
        state.bestRunStardust = state.bestRunSoFar
        state.omniverseBestRun = state.omniverseBestSoFar   // v4.0
        state.voidSparks += sparks
        state.lifetimeVoidSparks += sparks
        state.multiverseCount += 1
        state.realityFragments = .zero
        resetCosmos()
        state.lastSeen = Date()
        save()
        return sparks
    }

    /// Sparks to build or raise a Void Wonder; nil if maxed or unknown.
    func voidWonderCost(_ id: String) -> Big? {
        guard let w = VoidWonderCatalog.wonder(id: id) else { return nil }
        let level = state.wonderLevel(id)
        guard w.maxLevel == 0 || level < w.maxLevel else { return nil }
        return w.cost(toReachLevel: level + 1)
    }

    @discardableResult
    func buildVoidWonder(id: String) -> Bool {
        guard let w = VoidWonderCatalog.wonder(id: id), let cost = voidWonderCost(id) else { return false }
        guard state.multiverseCount >= w.multiverseRequired else { return false }
        guard state.voidSparks >= cost else { return false }
        state.voidSparks -= cost
        state.wonderLevels[id] = state.wonderLevel(id) + 1
        save()
        return true
    }

    // MARK: - Omniverse (v4.0, fourth prestige layer)

    /// Echoes a collapse would pay right now (best run since the last one).
    var availableEchoes: Big { OmniverseCalculator.echoesEarned(bestRun: state.omniverseBestSoFar) }
    var omniverseUnlocked: Bool { state.omniverseDoorOpen }
    var canCollapseOmniverse: Bool { omniverseUnlocked && availableEchoes > 0 }

    /// Transient: true the moment the door first opens, until the UI acknowledges it.
    private(set) var showOmniverseDoor = false
    func acknowledgeOmniverseDoor() { showOmniverseDoor = false }

    private func checkOmniverseDoor() {
        checkRift()
        guard !state.omniverseDoorOpen, state.lifetimeStardust >= Dilation.threshold else { return }
        state.omniverseDoorOpen = true
        showOmniverseDoor = true
        save()
    }

    /// Trade the Multiverse (sparks, Void Wonders, fragments) and everything a True
    /// Cosmos resets for Echoes, and restart the Cosmos Goal ladder. Kept: Cosmic
    /// Wonders, Omniverse nodes, cosmos and multiverse counts, achievements, stars,
    /// purchases, and Spark Memory's share of the sparks. Returns the Echoes earned.
    @discardableResult
    func omniverseCollapse() -> Big {
        let gained = availableEchoes
        guard canCollapseOmniverse, gained > 0 else { return .zero }
        checkChallenge()
        state.bestRunStardust = state.bestRunSoFar
        state.echoes += gained
        state.lifetimeEchoes += gained
        state.omniverseCount += 1
        let memory = min(state.omniverseLevel(OmniverseTree.sparkMemoryId), OmniverseTree.node(id: OmniverseTree.sparkMemoryId)?.maxLevel ?? 5)
        state.voidSparks = (state.voidSparks * (OmniverseTree.sparkMemoryPerLevel * Double(memory))).floored
        for w in VoidWonderCatalog.all { state.wonderLevels.removeValue(forKey: w.id) }
        state.realityFragments = .zero
        state.cosmosSinceOmniverse = 0
        state.omniverseBestRun = .zero
        resetCosmos()
        state.lastSeen = Date()
        save()
        return gained
    }

    /// Echoes for the next level of a node; nil if maxed or unknown.
    func omniverseNodeCost(_ id: String) -> Big? {
        guard let node = OmniverseTree.node(id: id) else { return nil }
        let level = state.omniverseLevel(id)
        guard node.maxLevel == 0 || level < node.maxLevel else { return nil }
        return node.cost(toReachLevel: level + 1)
    }

    @discardableResult
    func buyOmniverseNode(id: String) -> Bool {
        guard let cost = omniverseNodeCost(id), state.echoes >= cost else { return false }
        state.echoes -= cost
        state.omniverseLevels[id] = state.omniverseLevel(id) + 1
        save()
        return true
    }

    @ObservationIgnored private var lastOmniverseAutoAt: Date = .distantPast

    /// Cosmic Autopilot / Void Autopilot: at most one reset per 30 s, and only when
    /// it would at least double what the player holds (the rule the model plays by).
    /// Internal for tests.
    func omniverseAutomationStep(now: Date) {
        guard now.timeIntervalSince(lastOmniverseAutoAt) >= 30 else { return }
        guard !state.inRift(RiftCatalog.loneHandId) else { return }   // Rift rule: no automation
        if state.omniverseLevel(OmniverseTree.autoCollapseId) > 0, canCollapseMultiverse,
           availableSparks >= max(state.voidSparks, Big.one) {
            lastOmniverseAutoAt = now
            multiverseCollapse()
            return
        }
        if state.omniverseLevel(OmniverseTree.autoCosmosId) > 0, canTrueCosmos,
           availableFragments >= max(state.realityFragments, Big(50)) {
            lastOmniverseAutoAt = now
            trueCosmos()
        }
    }

    // MARK: - Rifts (v4.0 challenge runs)

    /// Open after the first Omniverse collapse.
    var riftsUnlocked: Bool { state.omniverseCount >= 1 }
    var activeRift: Rift? { state.activeRiftId.flatMap(RiftCatalog.rift(id:)) }
    /// Transient: the Rift whose tier was just completed (the UI shows it once).
    private(set) var completedRiftId: String?
    func acknowledgeRiftCompletion() { completedRiftId = nil }

    /// log10 goal the next tier of `id` would ask for if entered now; nil once all tiers are done.
    func riftGoalLog(for id: String) -> Double? {
        let tier = state.riftTier(id)
        guard tier < RiftCatalog.maxTier else { return nil }
        return RiftCatalog.goalLog(tierIndex: tier, bestRunLog: state.bestRunSoFar.log10Value)
    }

    /// Start a fresh run under the Rift's rule. The goal is fixed now (your best run
    /// keeps rising during the Rift, the target doesn't).
    @discardableResult
    func enterRift(_ id: String) -> Bool {
        guard riftsUnlocked, state.activeRiftId == nil, RiftCatalog.rift(id: id) != nil,
              let goal = riftGoalLog(for: id) else { return false }
        checkChallenge()
        state.bestRunStardust = state.bestRunSoFar
        state.cosmosBestRun = state.cosmosBestSoFar
        state.omniverseBestRun = state.omniverseBestSoFar
        state.activeRiftId = id
        state.riftGoalLog = goal
        state.stardust = CosmicTree.startingStardust(state.cosmicSkillLevels)
        state.lifetimeStardust = .zero
        state.generators = GameContent.defaultGenerators
        state.upgrades = GameContent.defaultUpgrades
        save()
        return true
    }

    /// Leave without completing: the rule ends, the run in progress carries on.
    func leaveRift() {
        guard state.activeRiftId != nil else { return }
        state.activeRiftId = nil
        state.riftGoalLog = 0
        save()
    }

    /// Completes the active Rift's tier once this run reaches its goal. Runs on every
    /// Stardust gain (via the Absolute / door checks).
    private func checkRift() {
        guard let id = state.activeRiftId, state.lifetimeStardust.log10Value >= state.riftGoalLog else { return }
        state.riftTiers[id] = min(RiftCatalog.maxTier, state.riftTier(id) + 1)
        state.activeRiftId = nil
        state.riftGoalLog = 0
        completedRiftId = id
        save()
    }

    // MARK: - Cosmic tree

    func cosmicSkillLevel(_ id: String) -> Int { state.cosmicSkillLevels[id] ?? 0 }

    /// Cosmic-shard cost of the next level or Stellar rank, or nil if maxed / unknown.
    func cosmicSkillCost(_ id: String) -> Big? {
        guard let skill = CosmicTree.skill(id) else { return nil }
        let lvl = cosmicSkillLevel(id)
        guard skill.canLevel(from: lvl) else { return nil }
        return skill.cost(atLevel: lvl)
    }

    @discardableResult
    func buyCosmicSkill(_ id: String) -> Bool {
        guard let skill = CosmicTree.skill(id) else { return false }
        let lvl = cosmicSkillLevel(id)
        guard skill.canLevel(from: lvl) else { return false }
        let cost = skill.cost(atLevel: lvl)
        guard state.cosmicShards >= cost else { return false }
        state.cosmicShards -= cost
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

    private func dailyStardust(_ mult: Double) -> Big {
        max(state.stardustPerSecond * (1800 * mult), Big(500))
    }

    private func reward(forStreak streak: Int) -> DailyReward {
        let day = ((streak - 1) % 7) + 1
        var stardust = Big.zero, shards = 0, boostHours = 0.0
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
    func claimDaily(multiplier: Double = 1) -> DailyReward {
        let streak = nextDailyStreak()
        // v3.4.1 — `multiplier` 2 when the player watched an ad to double it.
        let r = reward(forStreak: streak).scaled(by: max(1, multiplier))
        addStardust(r.stardust)
        state.totalDailyClaims += 1
        let shardGain = Double(r.cosmicShards) * CosmicEventScheduler.shardGrantMultiplier(state.activeEvent)
        state.cosmicShards += shardGain
        state.lifetimeCosmicShards += shardGain
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
        // v3.3 — Event Horizon Wonder: no cooldown, so a new event starts the moment one ends.
        guard state.hasEventHorizon
                || CosmicEventScheduler.canRoll(now: now, lastEventEnd: state.lastEventEndedAt) else { return }
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
    /// v3.2 — what a boost of `duration` actually lasts, Boost Extension
    /// included ("1h", "1h 40m", "24h 40m"). The Shop used to print a fixed
    /// "1 hour", so a maxed extension looked like it did nothing (App Store
    /// review, 12 Oct 2026).
    func boostLabel(_ duration: TimeInterval) -> String {
        let total = Int((duration + CosmicTree.boostExtensionSeconds(state.cosmicSkillLevels)) / 60)
        let h = total / 60, m = total % 60
        return m > 0 ? "\(h)h \(m)m" : "\(h)h"
    }

    func grantBoost(duration: TimeInterval) {
        let bonus = CosmicTree.boostExtensionSeconds(state.cosmicSkillLevels)
        let base = max(Date(), state.adBoostExpiresAt ?? .distantPast)
        state.adBoostExpiresAt = base.addingTimeInterval(duration + bonus)
        save()
    }

    /// v3.0: grant a timed Automation trial (rewarded-ad path). Same extend-from-max
    /// pattern as `grantBoost` — watching a second ad while a trial is still valid
    /// extends from the current expiry, not from "now", so no time is wasted.
    func grantAutomationTrial(hours: Double) {
        let base = max(Date(), state.automationTrialExpiresAt ?? .distantPast)
        state.automationTrialExpiresAt = base.addingTimeInterval(hours * 3600)
        save()
    }

    /// v3.0 Phase 2 — flip the per-generator auto-buy toggle. Removes the key when
    /// disabling so the persisted dict stays tidy.
    func setAutoBuy(generatorId: String, enabled: Bool) {
        if enabled {
            state.autoBuyEnabled[generatorId] = true
        } else {
            state.autoBuyEnabled.removeValue(forKey: generatorId)
        }
        save()
    }

    // MARK: - Phase 3: auto-Big-Bang

    /// v3.0 Phase 3 — same as `bigBang()` but stamps `lastAutoBangAt` for the
    /// automation cooldown, and deliberately bypasses the view-layer effects
    /// (BoostNudgeSheet, ReviewPrompter) that only fire from the manual
    /// `BigBangView.triggerBigBang()` path. Shard grant, prestige counter,
    /// GameCenter score, achievements — all identical to the manual path.
    @discardableResult
    func autoBigBang() -> Big {
        let shards = bigBang()
        if shards > 0 {
            state.lastAutoBangAt = Date()
            save()
        }
        return shards
    }

    func setAutoBigBangEnabled(_ enabled: Bool) {
        state.autoBigBangEnabled = enabled
        save()
    }

    func setAutoBigBangThreshold(_ threshold: Big) {
        state.autoBigBangThreshold = max(threshold, Big.one)
        save()
    }

    /// v3.1 — see `GameState.autoBigBangHoldForAbsolute`.
    func setAutoBigBangHoldForAbsolute(_ hold: Bool) {
        state.autoBigBangHoldForAbsolute = hold
        save()
    }

    /// v3.0 Phase 4 — flip the auto-buy Cosmic Tree toggle. Setter only; the
    /// actual step runs at the end of `bigBang()`.
    func setAutoBuyCosmicTree(_ enabled: Bool) {
        state.autoBuyCosmicTreeEnabled = enabled
        save()
    }

    // MARK: - v4.0.3 ad-boost cap

    /// v4.0.3 — the most 2× time a player can bank from rewarded ads. Before this every
    /// ad stacked another hour with no ceiling: one device watched 208 rewarded ads on
    /// 15 Nov 2026 (207 of them the Shop boost) and Cosmica Rewarded's CTR hit 23%, the
    /// pattern AdMob's invalid-traffic checks act on. The daily-reward boost shares the ad
    /// timer and isn't capped; the paid boost has its own timer (`grantPaidBoost`).
    static let adBoostBankCap: TimeInterval = 8 * 3600

    /// What one rewarded ad adds: an hour plus the Cosmic Tree "Boost Extension" bonus.
    var adBoostGrant: TimeInterval {
        3600 + CosmicTree.boostExtensionSeconds(state.cosmicSkillLevels)
    }

    /// v4.0.3 — true when another ad's hour would push the bank past the cap, so the
    /// Shop shows "Boost full" instead of offering an ad that grants nothing.
    func adBoostFull(now: Date = Date()) -> Bool {
        let left = max(0, (state.adBoostExpiresAt ?? .distantPast).timeIntervalSince(now))
        return left + adBoostGrant > Self.adBoostBankCap
    }

    /// v4.0.3 — the paid boost: its own 3× timer, extended from whichever is later (now or
    /// the current expiry), Boost Extension included. Multiplies with the ad boost.
    func grantPaidBoost(duration: TimeInterval) {
        let bonus = CosmicTree.boostExtensionSeconds(state.cosmicSkillLevels)
        let base = max(Date(), state.paidBoostExpiresAt ?? .distantPast)
        state.paidBoostExpiresAt = base.addingTimeInterval(duration + bonus)
        save()
    }

    /// v4.0.3 — the rewarded-ad boost. Same stacking as `grantBoost`, but the expiry
    /// never goes past `now + adBoostBankCap` (it never shortens a longer paid boost).
    func grantAdBoost(now: Date = Date()) {
        let base = max(now, state.adBoostExpiresAt ?? .distantPast)
        let capped = min(base.addingTimeInterval(adBoostGrant), now.addingTimeInterval(Self.adBoostBankCap))
        state.adBoostExpiresAt = max(base, capped)
        save()
    }

    /// Direct grant of Cosmic Shards (paid IAP, daily reward, cosmic event).
    /// Applies the active-event shard multiplier if any.
    func grantShards(_ amount: Big) {
        let mult = CosmicEventScheduler.shardGrantMultiplier(state.activeEvent)
        let gain = amount * mult
        guard gain > 0 else { return }
        state.cosmicShards += gain
        state.lifetimeCosmicShards += gain
        save()
    }

    /// v3.1 — what a Cosmic Shard pack grants: never less than its original
    /// fixed amount, and otherwise `multiple` × the player's latest Big Bang
    /// (or what a Big Bang would pay right now, if that's more). Keeps the
    /// packs meaningful at every stage instead of rounding to nothing late game.
    func shardPackAmount(base: Double, multiple: Double) -> Big {
        let reference = max(state.lastBigBangShards, availableShards)
        return max(reference * multiple, Big(base))
    }

    /// v3.4 shard packs, sized in Big Bangs (was 1 and 10). Kindling (3.3)
    /// tripled early Big Bangs and pack sales stopped: one Big Bang's worth no
    /// longer bought anything a player couldn't earn in minutes. Same price
    /// ratio between the two as before.
    static let smallShardPack = (base: 500.0, bigBangs: 3.0)
    static let largeShardPack = (base: 5_000.0, bigBangs: 30.0)
    /// v4.0.3 Shards Huge: 4x Large's shards. Launched at $19.99 (2x Large's shards per
    /// dollar); no sales in its first five days, so on 2026-11-23 the price dropped to
    /// $14.99 (price set in ASC only): 4x the shards for 1.5x Large's $9.99, ~2.7x per dollar.
    static let hugeShardPack = (base: 20_000.0, bigBangs: 120.0)

    /// v3.4 — the biggest single thing `amount` more shards would let the
    /// player buy that they can't afford now: a Cosmic Tree level or a Wonder.
    /// Lets a pack say what it's for instead of only how big it is. nil when
    /// nothing new comes into reach.
    func shardPackTarget(amount: Big) -> (name: String, cost: Big)? {
        let have = state.cosmicShards
        let budget = have + amount
        var best: (name: String, cost: Big)?
        func consider(_ name: String, _ cost: Big?) {
            guard let cost, cost > have, cost <= budget else { return }
            if best == nil || cost > best!.cost { best = (name, cost) }
        }
        for skill in CosmicTree.skills where !skill.id.hasPrefix("autonomy_") {
            consider(skill.name, cosmicSkillCost(skill.id))
        }
        for w in WondersCatalog.all where state.cosmosCount >= w.cosmosRequired {
            consider(w.title, wonderCost(w.id))
        }
        return best
    }

    /// v3.1 Time Warp — `hours` of production at the full online rate, right
    /// now. Scales with the player, unlike a fixed-amount pack. Counts toward
    /// this run's lifetime (tier, Big Bang reward, Absolute) like any earning.
    func timeWarpAmount(hours: Double) -> Big {
        max(state.stardustPerSecond * (hours * 3600), Big.zero)
    }

    @discardableResult
    func applyTimeWarp(hours: Double) -> Big {
        let amount = timeWarpAmount(hours: hours)
        guard amount > 0 else { return .zero }
        addStardust(amount)
        checkAbsoluteAscension()
        checkAchievements()
        checkChallenge()
        save()
        return amount
    }

    // MARK: - Free daily Time Warp (v3.4)

    /// Length of the once-a-day Time Warp a rewarded ad pays for.
    static let freeWarpHours: Double = 0.5

    /// One per calendar day (local), like the daily reward.
    func freeWarpAvailable(now: Date = Date()) -> Bool {
        guard let last = state.lastFreeWarpAt else { return true }
        return !Calendar.current.isDate(last, inSameDayAs: now)
    }

    /// Grants the free warp and stamps the day. Nothing is stamped when the
    /// warp would be worth nothing (no production yet), so the day isn't lost.
    @discardableResult
    func claimFreeWarp(now: Date = Date()) -> Big {
        guard freeWarpAvailable(now: now), timeWarpAmount(hours: Self.freeWarpHours) > 0 else { return .zero }
        state.lastFreeWarpAt = now
        return applyTimeWarp(hours: Self.freeWarpHours)   // saves
    }

    // MARK: - Offline Catch-Up (v3.4.1)

    /// The ad's cap (24h) and the IAP's (7 days), each plus the player's own
    /// cap bonuses (Night Watch, Chronosphere) so they always reach past the base cap.
    var adCatchUpCap: TimeInterval { OfflineAccrual.extendedCap + offlineCapBonuses }
    var iapCatchUpCap: TimeInterval { 7 * 24 * 3600 + offlineCapBonuses }
    private var offlineCapBonuses: TimeInterval {
        CosmicTree.offlineCapBonus(state.cosmicSkillLevels) + state.wonderOfflineCapBonus
    }

    /// Seconds of the last absence a `cap` would pay for that haven't been paid yet.
    func catchUpSeconds(cap: TimeInterval) -> TimeInterval {
        max(0, min(state.lastAwaySeconds, cap) - state.lastAwayPaidSeconds)
    }

    /// Stardust `applyOfflineCatchUp(cap:)` would pay right now.
    func offlineCatchUpAmount(cap: TimeInterval) -> Big {
        max(state.offlineStardustPerSecond * (catchUpSeconds(cap: cap) * OfflineAccrual.offlineRate), Big.zero)
    }

    /// Pays the part of the last absence the base cap cut off, up to `cap`.
    /// Before 3.4.1 this measured from `lastSeen`, which every save resets,
    /// so the ad and the $2.99 IAP both paid for a few seconds.
    @discardableResult
    func applyOfflineCatchUp(cap: TimeInterval) -> OfflineAccrual.Result {
        let secs = catchUpSeconds(cap: cap)
        let earned = offlineCatchUpAmount(cap: cap)
        addStardust(earned)
        state.lastAwayPaidSeconds += secs
        checkAbsoluteAscension()
        checkAchievements()
        checkChallenge()
        save()
        return OfflineAccrual.Result(
            stardustEarned: earned,
            secondsElapsed: state.lastAwaySeconds,
            secondsCounted: secs,
            capUsed: cap,
            wasCapped: state.lastAwaySeconds > cap
        )
    }

    // MARK: - Offline accrual

    @discardableResult
    func applyOffline(extended: Bool = false) -> OfflineAccrual.Result {
        let result = OfflineAccrual.compute(
            now: Date(),
            lastSeen: state.lastSeen,
            ratePerSecond: state.offlineStardustPerSecond,   // v3.3 — Night Shift + Time Lens
            extended: extended,
            extraCap: CosmicTree.offlineCapBonus(state.cosmicSkillLevels) + state.wonderOfflineCapBonus
        )
        addStardust(result.stardustEarned)
        // v3.4.1 — remember a real absence so Catch-Up can pay what the cap cut
        // off. A quick app switch doesn't replace a long night away.
        if result.secondsElapsed >= 300 {
            state.lastAwaySeconds = result.secondsElapsed
            state.lastAwayPaidSeconds = result.secondsCounted
        }
        state.lastSeen = Date()
        offlinePending = false   // v4.0.2 — paid; saves may stamp lastSeen again
        checkAbsoluteAscension()
        checkAchievements()
        checkChallenge()
        save()
        return result
    }

    // MARK: - Cosmic Wonders (v2.0)

    /// Shards to build (level 0 → 1) or upgrade a Wonder; nil if it's at its max level.
    func wonderCost(_ id: String) -> Big? {
        guard let wonder = WondersCatalog.wonder(id: id) else { return nil }
        let level = state.wonderLevel(id)
        guard wonder.maxLevel == 0 || level < wonder.maxLevel else { return nil }
        return wonder.cost(toReachLevel: level + 1)
    }

    /// Build a Wonder, or (v3.3) raise it a level. Fails silently if maxed, unknown,
    /// short of the Cosmos requirement, or short of shards. Shards spent do NOT
    /// reduce `lifetimeCosmicShards` — that's an earn-track, not a balance.
    @discardableResult
    func buildWonder(id: String) -> Bool {
        guard let wonder = WondersCatalog.wonder(id: id), let cost = wonderCost(id) else { return false }
        guard state.cosmosCount >= wonder.cosmosRequired else { return false }
        guard state.cosmicShards >= cost else { return false }
        state.cosmicShards -= cost
        state.wonderLevels[id] = state.wonderLevel(id) + 1
        state.builtWonderIds.insert(id)
        save()
        return true
    }

    // MARK: - Weekly Cosmic Challenge (v3.2)

    /// This week's challenge, or nil before the first `refreshChallenge`.
    var challenge: WeeklyChallenge? { WeeklyChallenge.stored(in: state) }

    var challengeClaimable: Bool { state.challengeCompleted && !state.challengeClaimed }

    /// Shards a challenge pays on top of its star: half a Big Bang at the
    /// player's level, never less than 25 (same sizing rule as the shard packs).
    var challengeRewardShards: Big { shardPackAmount(base: 25, multiple: 0.5) }

    /// When the week has changed, pay out any unclaimed reward from the week
    /// that ended, then set this week's challenge. An Int compare when nothing
    /// changed, so it's safe to call every tick.
    func refreshChallenge(now: Date = Date()) {
        let week = WeeklyChallenge.week(for: now)
        guard week != state.challengeWeek else { return }
        if challengeClaimable { grantChallengeReward(week: state.challengeWeek) }
        let c = WeeklyChallenge.make(week: week, state: state, now: now)
        state.challengeWeek = c.week
        state.challengeKindRaw = c.kind.rawValue
        state.challengeBaseline = c.baseline
        state.challengeTarget = c.target
        state.challengeCompleted = false
        state.challengeClaimed = false
        save()
    }

    /// Latch completion the moment the goal is met. Called from the tick and
    /// just before anything that resets a run. Internal (not private) for tests.
    func checkChallenge() {
        checkTrail()
        guard !state.challengeCompleted, let c = challenge, c.isMet(state) else { return }
        state.challengeCompleted = true
        save()
    }

    /// Claim a completed challenge: +1 Challenge Star and the shard reward.
    /// Returns the shards granted (0 if there was nothing to claim).
    @discardableResult
    func claimChallenge() -> Big {
        guard challengeClaimable else { return .zero }
        return grantChallengeReward(week: state.challengeWeek)
    }

    @discardableResult
    private func grantChallengeReward(week: Int) -> Big {
        let shards = challengeRewardShards
        state.challengeStars += 1
        state.challengeStreak = state.lastChallengeClaimWeek == week - 1 ? state.challengeStreak + 1 : 1
        state.lastChallengeClaimWeek = week
        state.challengeClaimed = true
        grantShards(shards)   // saves
        checkAchievements()
        return shards
    }

    // MARK: - Seasonal Trails (v4.0.4 Winter Solstice, v4.0.5 Binary Stars)

    /// Shards one trail goal pays: a Big Bang's worth at the player's level (min 50).
    var trailRewardShards: Big {
        shardPackAmount(base: SeasonalTrails.shardsPerStepFloor, multiple: SeasonalTrails.shardsPerStepBigBangs)
    }

    /// The trail this save is running (goals set), if any.
    var trailEvent: TrailEvent? {
        state.solsticeTargets.isEmpty ? nil : SeasonalTrails.event(id: state.trailEventId)
    }

    /// After a trail's window: pay goals met but not claimed, then clear it. Inside a window:
    /// set that trail's goals once. Cheap when nothing changes (called every tick).
    func refreshTrail(now: Date = Date()) {
        if let ev = trailEvent, now >= ev.end {
            for step in ev.steps where trailClaimable(step) { grantTrail(step, ev) }
            clearTrail()
        } else if trailEvent == nil, !state.solsticeTargets.isEmpty || !state.trailEventId.isEmpty {
            clearTrail()   // unknown id (shouldn't happen): start clean
        }
        guard let open = SeasonalTrails.open(now), state.trailEventId != open.id else { return }
        if let ev = trailEvent {   // a different trail still stored (overlap can't happen, but settle it)
            for step in ev.steps where trailClaimable(step) { grantTrail(step, ev) }
        }
        state.solsticeBaselines = [:]; state.solsticeTargets = [:]
        state.solsticeMet = []; state.solsticeClaimed = []
        for (step, goal) in SeasonalTrails.make(open, state) {
            state.solsticeBaselines[step.rawValue] = goal.base
            state.solsticeTargets[step.rawValue] = goal.target
        }
        state.trailEventId = open.id
        save()
    }

    private func clearTrail() {
        state.solsticeBaselines = [:]; state.solsticeTargets = [:]
        state.solsticeMet = []; state.solsticeClaimed = []
        state.trailEventId = ""
        save()
    }

    /// Latch goals the moment they're met. Runs with `checkChallenge` (every tick and
    /// before anything that resets a run), only while the trail's window is open.
    func checkTrail(now: Date = Date()) {
        guard let ev = trailEvent, ev.isOpen(now), state.solsticeMet.count < ev.steps.count else { return }
        var changed = false
        for step in ev.steps where !SeasonalTrails.isMet(step, state) {
            if SeasonalTrails.reached(step, state) {
                state.solsticeMet.append(step.rawValue)
                changed = true
            }
        }
        if changed { save() }
    }

    func trailClaimable(_ step: TrailStep) -> Bool {
        SeasonalTrails.isMet(step, state) && !SeasonalTrails.isClaimed(step, state)
    }

    /// Claim one met goal. Returns the shards granted (0 if nothing to claim).
    @discardableResult
    func claimTrail(_ step: TrailStep) -> Big {
        guard let ev = trailEvent, trailClaimable(step) else { return .zero }
        return grantTrail(step, ev)
    }

    @discardableResult
    private func grantTrail(_ step: TrailStep, _ ev: TrailEvent) -> Big {
        let shards = trailRewardShards
        state.solsticeClaimed.append(step.rawValue)
        if SeasonalTrails.claimedCount(ev, state) == ev.steps.count && !state.trailOrbsEarned.contains(ev.id) {
            state.trailOrbsEarned.append(ev.id)
            if ev.id == SeasonalTrails.solsticeId { state.solsticeOrbEarned = true }
            state.challengeStars += 1
        }
        grantShards(shards)   // saves
        checkAchievements()
        return shards
    }

    // MARK: - Persistence

    /// v4.0.2 — true from launch, and again from backgrounding, until `applyOffline()` has
    /// paid the absence. While it's true `save()` leaves `lastSeen` alone: any save in that
    /// window (the Doubler/Ultimate entitlement arriving during `iap.start()`, an iCloud
    /// adopt) used to stamp `lastSeen = now`, and the welcome-back sheet then said
    /// "away 0s" and paid a fraction of a second (App Store review, 13 Nov 2026).
    private(set) var offlinePending = true

    /// v4.0.2 — the app is going to the background: stamp the moment play stopped, stop the
    /// tick (a stale tick on return used to pay or drop the whole absence at random), and
    /// leave the absence for `applyOffline()` when the player comes back.
    func enterBackground() {
        offlinePending = false
        save()
        stop()
        offlinePending = true
    }

    func save() {
        if !offlinePending { state.lastSeen = Date() }
        try? persistence.save(state: state)
    }
}
