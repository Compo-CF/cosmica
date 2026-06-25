import Foundation

struct GameState: Codable {
    // Save format versioning — bump when a breaking schema change ships
    var saveVersion: Int = 1

    // Currencies
    var stardust: Double = 0
    var lifetimeStardust: Double = 0
    var cosmicShards: Double = 0

    // Progression
    var prestigeCount: Int = 0
    var totalTaps: Int = 0
    var firstLaunch: Date = Date()
    var lastSeen: Date = Date()

    // Content
    var generators: [Generator] = GameContent.defaultGenerators
    var upgrades: [Upgrade] = GameContent.defaultUpgrades

    // Boosts
    var adBoostExpiresAt: Date? = nil
    var removeAdsOwned: Bool = false

    // ───────── Derived (not persisted by Codable choice — recomputed each frame) ─────────

    var currentTier: Tier {
        Tier.current(forLifetime: lifetimeStardust)
    }

    var shardMultiplier: Double {
        1.0 + (cosmicShards * 0.02)
    }

    var adBoostMultiplier: Double {
        guard let exp = adBoostExpiresAt, Date() < exp else { return 1.0 }
        return 2.0
    }

    var totalMultiplier: Double {
        currentTier.multiplier * shardMultiplier * adBoostMultiplier
    }

    /// Base stardust per second across all generators with their per-generator upgrades applied,
    /// then scaled by tier × shards × ad-boost.
    var stardustPerSecond: Double {
        let base = generators.reduce(0.0) { sum, g in sum + g.ratePerSecond(with: upgrades) }
        let globalUpgradeMult = upgrades
            .filter { $0.purchased && $0.isGlobal }
            .reduce(1.0) { $0 * $1.multiplier }
        return base * globalUpgradeMult * totalMultiplier
    }

    /// Value of a single manual tap. Always at least 1, otherwise 1/10th of a second of automated production.
    var tapValue: Double {
        max(1.0, stardustPerSecond * 0.1)
    }
}
