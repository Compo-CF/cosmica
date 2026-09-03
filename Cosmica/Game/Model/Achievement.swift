import Foundation

/// A permanent goal the player can satisfy exactly once. Every unlocked Achievement
/// adds a small flat bonus to `GameState.totalMultiplier` via `AchievementCatalog.multiplier`,
/// so this system is a slow, cumulative "engagement dividend" rather than another prestige loop.
struct Achievement: Identifiable, Codable, Hashable {
    let id: String
    let title: String
    let detail: String
    let symbol: String
    let tier: AchievementTier
    let goal: AchievementGoal
}

/// Bronze / Silver / Gold / Platinum — determines the multiplier bonus and the ring color.
/// Bonuses stack additively (see `AchievementCatalog.multiplier`).
enum AchievementTier: String, Codable, CaseIterable {
    case bronze, silver, gold, platinum

    /// Flat additive contribution to `totalMultiplier`. 25 achievements, mostly bronze/silver,
    /// cap the fully-cleared bonus around ×1.35 — meaningful without eclipsing shard/tree math.
    var bonus: Double {
        switch self {
        case .bronze:   return 0.005
        case .silver:   return 0.010
        case .gold:     return 0.020
        case .platinum: return 0.050
        }
    }

    var label: String {
        switch self {
        case .bronze:   return "Bronze"
        case .silver:   return "Silver"
        case .gold:     return "Gold"
        case .platinum: return "Platinum"
        }
    }
}

/// The rule that decides when an Achievement is satisfied. Each case knows how to read
/// the running `GameState` — no engine-side dispatch table needed.
enum AchievementGoal: Codable, Hashable {
    case taps(Int)
    case lifetimeStardust(Double)
    case cosmicShards(Double)
    case lifetimeCosmicShards(Double)
    case prestigeCount(Int)
    case cosmosCount(Int)
    case realityFragments(Double)
    case ownGenerator(index: Int, count: Int)
    case ownAllGenerators(count: Int)
    case treeLevelsTotal(Int)
    case specializationsChosen(Int)

    func isMet(state: GameState) -> Bool {
        switch self {
        case .taps(let n):                   return state.totalTaps >= n
        case .lifetimeStardust(let v):       return state.lifetimeStardust >= v
        case .cosmicShards(let v):           return state.cosmicShards >= v
        case .lifetimeCosmicShards(let v):   return state.lifetimeCosmicShards >= v
        case .prestigeCount(let n):          return state.prestigeCount >= n
        case .cosmosCount(let n):            return state.cosmosCount >= n
        case .realityFragments(let v):       return state.realityFragments >= v
        case .ownGenerator(let i, let c):
            guard i < state.generators.count else { return false }
            return state.generators[i].count >= c
        case .ownAllGenerators(let c):
            return !state.generators.isEmpty && state.generators.allSatisfy { $0.count >= c }
        case .treeLevelsTotal(let n):
            return state.cosmicSkillLevels.values.reduce(0, +) >= n
        case .specializationsChosen(let n):
            return state.generators.filter { $0.specialization != nil }.count >= n
        }
    }

    /// 0…1 for progress bars. Read-only — never mutates state.
    func progress(state: GameState) -> Double {
        switch self {
        case .taps(let n):                   return clamped(Double(state.totalTaps), Double(n))
        case .lifetimeStardust(let v):       return clamped(state.lifetimeStardust, v)
        case .cosmicShards(let v):           return clamped(state.cosmicShards, v)
        case .lifetimeCosmicShards(let v):   return clamped(state.lifetimeCosmicShards, v)
        case .prestigeCount(let n):          return clamped(Double(state.prestigeCount), Double(n))
        case .cosmosCount(let n):            return clamped(Double(state.cosmosCount), Double(n))
        case .realityFragments(let v):       return clamped(state.realityFragments, v)
        case .ownGenerator(let i, let c):
            guard i < state.generators.count else { return 0 }
            return clamped(Double(state.generators[i].count), Double(c))
        case .ownAllGenerators(let c):
            guard !state.generators.isEmpty else { return 0 }
            let per = state.generators.map { min(1.0, Double($0.count) / Double(c)) }
            return per.reduce(0, +) / Double(per.count)
        case .treeLevelsTotal(let n):
            return clamped(Double(state.cosmicSkillLevels.values.reduce(0, +)), Double(n))
        case .specializationsChosen(let n):
            return clamped(Double(state.generators.filter { $0.specialization != nil }.count), Double(n))
        }
    }

    private func clamped(_ current: Double, _ target: Double) -> Double {
        guard target > 0 else { return current > 0 ? 1 : 0 }
        return min(1, max(0, current / target))
    }
}

/// The read-only catalog of every shipping achievement, plus catalog-level helpers.
/// Ordering here also drives the on-screen order in `AchievementsView`.
enum AchievementCatalog {
    static let all: [Achievement] = [
        // ─── Tap milestones ──────────────────────────────────────────
        Achievement(id: "tap_100",  title: "First Sparks", detail: "Tap 100 times",     symbol: "hand.tap.fill", tier: .bronze, goal: .taps(100)),
        Achievement(id: "tap_1k",   title: "Steady Hand",  detail: "Tap 1,000 times",   symbol: "hand.tap.fill", tier: .silver, goal: .taps(1_000)),
        Achievement(id: "tap_10k",  title: "Percussive",   detail: "Tap 10,000 times",  symbol: "hand.tap.fill", tier: .gold,   goal: .taps(10_000)),

        // ─── Lifetime Stardust milestones ────────────────────────────
        Achievement(id: "sd_1k",    title: "Small Nebula",  detail: "Reach 1K lifetime ✦",   symbol: "sparkles", tier: .bronze,   goal: .lifetimeStardust(1_000)),
        Achievement(id: "sd_1m",    title: "Star Cluster",  detail: "Reach 1M lifetime ✦",   symbol: "sparkles", tier: .silver,   goal: .lifetimeStardust(1_000_000)),
        Achievement(id: "sd_1b",    title: "Galactic",      detail: "Reach 1B lifetime ✦",   symbol: "sparkles", tier: .gold,     goal: .lifetimeStardust(1_000_000_000)),
        Achievement(id: "sd_1qa",   title: "Supercluster",  detail: "Reach 1Qa lifetime ✦",  symbol: "sparkles", tier: .platinum, goal: .lifetimeStardust(1e15)),

        // ─── Cosmic Shards ───────────────────────────────────────────
        Achievement(id: "cs_10",    title: "First Shards",    detail: "Hold 10 Cosmic Shards",  symbol: "diamond.fill", tier: .bronze,   goal: .cosmicShards(10)),
        Achievement(id: "cs_500",   title: "Shard Collector", detail: "Hold 500 Cosmic Shards", symbol: "diamond.fill", tier: .gold,     goal: .cosmicShards(500)),
        Achievement(id: "lcs_1k",   title: "Diamond Hoarder", detail: "Earn 1,000 lifetime ◈",  symbol: "diamond.fill", tier: .platinum, goal: .lifetimeCosmicShards(1_000)),

        // ─── Prestige (Big Bang) ─────────────────────────────────────
        Achievement(id: "prestige_1",  title: "Big Bang!",        detail: "Prestige for the first time", symbol: "burst.fill", tier: .silver,   goal: .prestigeCount(1)),
        Achievement(id: "prestige_10", title: "Reborn Ten Times", detail: "Prestige 10 times",           symbol: "burst.fill", tier: .gold,     goal: .prestigeCount(10)),
        Achievement(id: "prestige_50", title: "Cyclic",           detail: "Prestige 50 times",           symbol: "burst.fill", tier: .platinum, goal: .prestigeCount(50)),

        // ─── Meta-prestige (True Cosmos) ─────────────────────────────
        Achievement(id: "cosmos_1",   title: "Realm-Walker",     detail: "Collapse one cosmos",  symbol: "infinity.circle.fill", tier: .platinum, goal: .cosmosCount(1)),
        Achievement(id: "cosmos_5",   title: "Multiverse",       detail: "Collapse 5 cosmoi",    symbol: "infinity.circle.fill", tier: .platinum, goal: .cosmosCount(5)),
        Achievement(id: "cosmos_20",  title: "Absolute Weaver",  detail: "Collapse 20 cosmoi",   symbol: "infinity.circle.fill", tier: .platinum, goal: .cosmosCount(20)),

        // ─── Reality Fragments ───────────────────────────────────────
        Achievement(id: "rf_10",  title: "Ten Fragments",     detail: "Hold 10 Reality Fragments",  symbol: "sparkle", tier: .gold,     goal: .realityFragments(10)),
        Achievement(id: "rf_100", title: "A Hundred Slivers", detail: "Hold 100 Reality Fragments", symbol: "sparkle", tier: .platinum, goal: .realityFragments(100)),

        // ─── Generator breadth ───────────────────────────────────────
        Achievement(id: "gen1_10",      title: "Newborn Cluster", detail: "Own 10 of the first generator",    symbol: "scope", tier: .bronze,   goal: .ownGenerator(index: 0, count: 10)),
        Achievement(id: "all_gen_1",    title: "Every Tool",      detail: "Own at least 1 of every generator", symbol: "scope", tier: .silver,  goal: .ownAllGenerators(count: 1)),
        Achievement(id: "all_gen_25",   title: "Full Fleet",      detail: "Own 25 of every generator",         symbol: "scope", tier: .gold,     goal: .ownAllGenerators(count: 25)),
        Achievement(id: "all_gen_100",  title: "Overkill",        detail: "Own 100 of every generator",        symbol: "scope", tier: .platinum, goal: .ownAllGenerators(count: 100)),

        // ─── Cosmic Tree ─────────────────────────────────────────────
        Achievement(id: "tree_10", title: "Rooted", detail: "Buy 10 tree skill levels total", symbol: "leaf.fill", tier: .bronze, goal: .treeLevelsTotal(10)),
        Achievement(id: "tree_50", title: "Canopy", detail: "Buy 50 tree skill levels total", symbol: "leaf.fill", tier: .gold,   goal: .treeLevelsTotal(50)),

        // ─── Specializations ─────────────────────────────────────────
        Achievement(id: "spec_1", title: "Specialist",        detail: "Choose one generator specialization",   symbol: "gearshape.2.fill", tier: .silver,   goal: .specializationsChosen(1)),
        Achievement(id: "spec_5", title: "Master Specialist", detail: "Choose 5 generator specializations",    symbol: "gearshape.2.fill", tier: .platinum, goal: .specializationsChosen(5)),
    ]

    static func achievement(id: String) -> Achievement? {
        all.first(where: { $0.id == id })
    }

    /// Achievements newly satisfied by `state` that are not yet in `unlocked`.
    /// Engine calls this every tick and folds the return into the unlocked set.
    static func newlyMet(state: GameState, unlocked: Set<String>) -> [Achievement] {
        all.filter { !unlocked.contains($0.id) && $0.goal.isMet(state: state) }
    }

    /// Cumulative +earnings multiplier from every unlocked achievement.
    /// 1.0 with none; ~1.35 with all 25 satisfied.
    static func multiplier(unlocked: Set<String>) -> Double {
        1.0 + unlocked.compactMap { achievement(id: $0)?.tier.bonus }.reduce(0, +)
    }
}
