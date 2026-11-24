import Foundation

/// Ad capture only — `-cosmicaAdClip a|b|c` (always together with `-cosmicaDemo`, so
/// the save stays in memory and iCloud / Game Center / ads / consent are skipped).
/// Each scene starts from a state that films well for the Meta app-install test:
///   a — a fresh run on a mid-game save: automation buying generators, numbers climbing
///   b — a big run ready to Big Bang for ~25× the shards held
///   c — the late-game demo save (every layer open) with automation running, for the
///       layer tour and a Rift run
/// Inert without the argument: `scene` is nil and nothing here is read.
/// Driven by CosmicaUITests/AdClipsUITests and .github/workflows/ad-clips.yml.
enum AdClipMode {
    static let argument = "-cosmicaAdClip"

    static var scene: String? {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: argument), i + 1 < args.count else { return nil }
        return args[i + 1]
    }

    static var isActive: Bool { scene != nil }

    /// The scene's starting save, or nil when no ad clip was asked for.
    static func state(now: Date = Date()) -> GameState? {
        switch scene {
        case "a": return numbers(now: now)
        case "b": return bigBang(now: now)
        case "c": return layers(now: now)
        default:  return nil
        }
    }

    /// A first-cosmos player a dozen Big Bangs in: regular tree levels, automation on.
    private static func midGame(now: Date, shards: Double) -> GameState {
        var s = GameState()
        s.firstLaunch = now            // < 2 days: the rating prompt never fires
        s.lastSeen = now
        s.lastDailyClaim = now         // no daily-reward sheet
        s.dailyStreak = 6
        s.lastEventEndedAt = now       // no Cosmic Event banner during the take
        s.cosmicShards = Big(shards)
        s.lifetimeCosmicShards = Big(shards * 2)
        s.prestigeCount = 11           // the Big Bang makes it 12: no boost nudge (3/7/15)
        s.totalBigBangs = 11
        s.totalTaps = 9_400
        s.challengeStars = 3
        s.cosmicSkillLevels = ["focus": 12, "harvest": 12, "deep_field": 8, "wormhole": 8,
                               "multiverse": 8, "chronal": 8, "big_bang": 6, "tap_mastery": 8,
                               "vanguard": 1, "autonomy_nexus": 1, "autonomy_absolute": 1]
        enableAutomation(&s, now: now)
        return s
    }

    private static func enableAutomation(_ s: inout GameState, now: Date) {
        s.automationTrialExpiresAt = now.addingTimeInterval(4 * 3600 - 600)
        for g in s.generators { s.autoBuyEnabled[g.id] = true }
    }

    /// a — the run starts at 1K ✦ with nothing built; ~1.2B shards held (×24M).
    private static func numbers(now: Date) -> GameState {
        var s = midGame(now: now, shards: 1.2e9)
        s.stardust = Big(1_000)
        s.lifetimeStardust = Big(1_000)
        s.bestRunStardust = Big(4.0e16)
        return s
    }

    /// b — 50K shards held, a run at 1.8e19 lifetime worth ~1.2M shards.
    private static func bigBang(now: Date) -> GameState {
        var s = midGame(now: now, shards: 5.0e4)
        let counts = [260, 240, 220, 200, 180, 160, 140, 120, 90, 70, 55, 42, 30, 22, 15, 8]
        for i in s.generators.indices { s.generators[i].count = counts[min(i, counts.count - 1)] }
        s.totalGeneratorsBought = Double(counts.reduce(0, +))
        s.stardust = Big(6.0e18)
        s.lifetimeStardust = Big(1.8e19)
        s.bestRunStardust = Big(2.0e19)
        return s
    }

    /// c — the CI demo save (every layer open), with automation buying generators.
    private static func layers(now: Date) -> GameState {
        var s = DemoMode.state(now: now)
        s.lastEventEndedAt = now
        enableAutomation(&s, now: now)
        return s
    }
}
