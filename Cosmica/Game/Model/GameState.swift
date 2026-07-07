import Foundation

/// Player state persisted to disk (and mirrored to CloudKit). Every stored field has
/// a default so `GameState()` yields a fresh save; a custom `init(from:)` below uses
/// `decodeIfPresent` for every key so v1.0.x saves that lack the v2 fields load
/// cleanly instead of throwing (which would silently wipe existing players' progress).
struct GameState: Codable {
    // Save format versioning — bump when a breaking schema change ships
    var saveVersion: Int = 2

    // ───────── Currencies ─────────
    var stardust: Double = 0
    var lifetimeStardust: Double = 0
    var cosmicShards: Double = 0

    // ───────── Progression ─────────
    var prestigeCount: Int = 0
    var totalTaps: Int = 0
    var firstLaunch: Date = Date()
    var lastSeen: Date = Date()

    // ───────── Content ─────────
    var generators: [Generator] = GameContent.defaultGenerators
    var upgrades: [Upgrade] = GameContent.defaultUpgrades

    // ───────── Cosmic tree ─────────
    var cosmicSkillLevels: [String: Int] = [:]

    // ───────── Daily rewards ─────────
    var lastDailyClaim: Date? = nil
    var dailyStreak: Int = 0

    // ───────── Cosmic Events (timed buff windows) ─────────
    var activeEventId: String? = nil
    var activeEventExpiresAt: Date? = nil
    var lastEventEndedAt: Date? = nil

    // ───────── Boosts ─────────
    var adBoostExpiresAt: Date? = nil
    var removeAdsOwned: Bool = false

    // ───────── Codable: lenient decode so v1.0.x saves migrate to v2 ─────────

    init() {}   // memberwise-equivalent default init for fresh saves.

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        saveVersion         = try c.decodeIfPresent(Int.self,           forKey: .saveVersion)         ?? 2
        stardust            = try c.decodeIfPresent(Double.self,        forKey: .stardust)            ?? 0
        lifetimeStardust    = try c.decodeIfPresent(Double.self,        forKey: .lifetimeStardust)    ?? 0
        cosmicShards        = try c.decodeIfPresent(Double.self,        forKey: .cosmicShards)        ?? 0
        prestigeCount       = try c.decodeIfPresent(Int.self,           forKey: .prestigeCount)       ?? 0
        totalTaps           = try c.decodeIfPresent(Int.self,           forKey: .totalTaps)           ?? 0
        firstLaunch         = try c.decodeIfPresent(Date.self,          forKey: .firstLaunch)         ?? Date()
        lastSeen            = try c.decodeIfPresent(Date.self,          forKey: .lastSeen)            ?? Date()
        generators          = try c.decodeIfPresent([Generator].self,   forKey: .generators)          ?? GameContent.defaultGenerators
        upgrades            = try c.decodeIfPresent([Upgrade].self,     forKey: .upgrades)            ?? GameContent.defaultUpgrades
        cosmicSkillLevels   = try c.decodeIfPresent([String: Int].self, forKey: .cosmicSkillLevels)   ?? [:]
        lastDailyClaim      = try c.decodeIfPresent(Date.self,          forKey: .lastDailyClaim)
        dailyStreak         = try c.decodeIfPresent(Int.self,           forKey: .dailyStreak)         ?? 0
        activeEventId       = try c.decodeIfPresent(String.self,        forKey: .activeEventId)
        activeEventExpiresAt = try c.decodeIfPresent(Date.self,         forKey: .activeEventExpiresAt)
        lastEventEndedAt    = try c.decodeIfPresent(Date.self,          forKey: .lastEventEndedAt)
        adBoostExpiresAt    = try c.decodeIfPresent(Date.self,          forKey: .adBoostExpiresAt)
        removeAdsOwned      = try c.decodeIfPresent(Bool.self,          forKey: .removeAdsOwned)      ?? false
    }

    // ───────── Derived (not persisted by Codable choice — recomputed each frame) ─────────

    var currentTier: Tier {
        Tier.current(forLifetime: lifetimeStardust)
    }

    /// Passive multiplier from *un-spent* Cosmic Shards. Spending shards on the Cosmic tree
    /// reduces this — a real invest-or-hoard tradeoff every Big Bang.
    var shardMultiplier: Double {
        1.0 + (cosmicShards * 0.02)
    }

    var adBoostMultiplier: Double {
        guard let exp = adBoostExpiresAt, Date() < exp else { return 1.0 }
        return 2.0
    }

    /// The currently active `CosmicEvent`, or nil if the window has expired.
    var activeEvent: CosmicEvent? {
        guard let id = activeEventId,
              let exp = activeEventExpiresAt,
              Date() < exp
        else { return nil }
        return CosmicEventCatalog.event(id: id)
    }

    /// Product of Cosmic-tree "Harvest Moon" × active-event ✦/s multiplier.
    /// Applied on top of tier × shards × ad boost.
    var eventStardustMultiplier: Double {
        CosmicEventScheduler.stardustPerSecondMultiplier(activeEvent)
    }

    /// Full multiplier stack on Stardust production.
    var totalMultiplier: Double {
        currentTier.multiplier
        * shardMultiplier
        * adBoostMultiplier
        * CosmicTree.focusMultiplier(cosmicSkillLevels)
        * CosmicTree.harvestMultiplier(cosmicSkillLevels)
        * eventStardustMultiplier
    }

    /// Base stardust per second across all generators, with each generator's tier-cluster
    /// tree buff, per-generator upgrades, and specialization applied.
    var stardustPerSecond: Double {
        let base = generators.reduce(0.0) { sum, g in
            let tierMult = CosmicTree.generatorTierMultiplier(g.index, cosmicSkillLevels)
            return sum + g.ratePerSecond(with: upgrades) * tierMult
        }
        let globalUpgradeMult = upgrades
            .filter { $0.purchased && $0.isGlobal }
            .reduce(1.0) { $0 * $1.multiplier }
        return base * globalUpgradeMult * totalMultiplier
    }

    /// Value of a single manual tap.
    /// = max(1, one-tenth of a second of automated production) × tap-mastery × active-event tap boost.
    var tapValue: Double {
        let base = max(1.0, stardustPerSecond * 0.1)
        return base * CosmicTree.tapMultiplier(cosmicSkillLevels) * CosmicEventScheduler.tapMultiplier(activeEvent)
    }
}
