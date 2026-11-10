import Foundation

/// v4.0 — `-cosmicaDemo` launch argument: a rich late-game save held in memory, for the
/// CI screenshot run (CosmicaUITests) and the 4.0 visual audit. Never touches the real
/// save: persistence is in-memory, iCloud / Game Center / ads / consent are skipped,
/// and the first-run sheets are marked seen so nothing covers the screens.
enum DemoMode {
    static let argument = "-cosmicaDemo"
    static var isActive: Bool { ProcessInfo.processInfo.arguments.contains(argument) }

    /// Every layer open: past the Omniverse door, a few collapses in, nodes bought.
    static func state(now: Date = Date()) -> GameState {
        var s = GameState()
        s.firstLaunch = now
        s.lastSeen = now
        s.lastDailyClaim = now
        s.dailyStreak = 12
        for i in s.generators.indices { s.generators[i].count = max(25, 400 - i * 20) }
        s.stardust = Big(mantissa: 4.2, exponent: 318)
        s.lifetimeStardust = Big(mantissa: 9.1, exponent: 321)
        s.cosmicShards = Big(mantissa: 3.3, exponent: 41)
        s.lifetimeCosmicShards = Big(mantissa: 8.0, exponent: 41)
        s.prestigeCount = 37
        s.totalBigBangs = 1_204
        s.totalTaps = 48_000
        s.absoluteAscendedAt = now.addingTimeInterval(-20 * 86_400)
        s.absoluteCelebrationShown = true
        s.realityFragments = Big(4.4e6)
        s.lifetimeRealityFragments = Big(2.1e9)
        s.cosmosCount = 64
        s.cosmosSinceOmniverse = 9
        s.voidSparks = Big(186)
        s.lifetimeVoidSparks = Big(9_400)
        s.multiverseCount = 11
        s.echoes = Big(42)
        s.lifetimeEchoes = Big(170)
        s.omniverseCount = 4
        s.omniverseDoorOpen = true
        s.omniverseBestRun = Big(mantissa: 9.1, exponent: 321)
        // No autopilots: they would True Cosmos at launch and every screen would show 0 ✦.
        s.omniverseLevels = [OmniverseTree.veilId: 3, OmniverseTree.sparkMemoryId: 1]
        s.cosmicSkillLevels = Dictionary(uniqueKeysWithValues: CosmicTree.skills.map { ($0.id, $0.maxLevel) })
        for w in WondersCatalog.all { s.wonderLevels[w.id] = w.maxLevel == 1 ? 1 : 6; s.builtWonderIds.insert(w.id) }
        for w in VoidWonderCatalog.all { s.wonderLevels[w.id] = 2 }
        s.unlockedAchievementIds = Set(AchievementCatalog.all.prefix(AchievementCatalog.all.count - 6).map(\.id))
        s.challengeStars = 9
        return s
    }

    /// Mark every first-run sheet as seen (UserDefaults keys the views read).
    static func prepareDefaults(_ defaults: UserDefaults = .standard) {
        for key in ["hasSeenOnboarding", "hasSeenWhatsNew_3_4"] { defaults.set(true, forKey: key) }
    }
}
