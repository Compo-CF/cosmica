import Foundation

/// v4.0.4 / v4.0.5 — Seasonal Trails: time-limited events that match the App Store In-App Events.
/// Each trail has a fixed UTC window and five goals, set the first time the player opens the game
/// inside the window and sized to their own progress. Each goal pays one Big Bang's worth of
/// Cosmic Shards when claimed; claiming all five pays a Challenge Star (+10% earnings, forever)
/// and the trail's orb skin, which can only be earned during that event and is kept for good.
/// Goals met but not claimed when the window closes are paid automatically.
///
/// Goals read never-reset lifetime counters, so a Big Bang never erases progress; the single-run
/// goal latches the moment it's met. Only one trail runs at a time.
///
/// 4.0.4 shipped the Winter Solstice Trail alone; its save keys (`solstice*`) now hold whichever
/// trail is running, named by `GameState.trailEventId`.
enum TrailStep: String, CaseIterable, Identifiable {
    case dailies, taps, bigBangs, generators, weeklies, bestRun

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .dailies:    return "calendar"
        case .taps:       return "hand.tap.fill"
        case .bigBangs:   return "burst.fill"
        case .generators: return "scope"
        case .weeklies:   return "star.circle.fill"
        case .bestRun:    return "chart.line.uptrend.xyaxis"
        }
    }
}

struct TrailRGB: Equatable { let r, g, b: Double }

/// How big each goal is (see `SeasonalTrails.make`).
struct TrailSizes: Equatable {
    var dailies: Double = 5
    var taps: Double = 2_500
    var bigBangsFirst: Double = 1
    var bigBangsManual: Double = 10
    var bigBangsAuto: Double = 50
    var generatorsManual: Double = 1_000
    var generatorsAuto: Double = 25_000
    var weeklies: Double = 2
    /// The single-run goal: × this the best run so far, min 1e9.
    var bestRunFactor: Double = 100
}

struct TrailEvent: Identifiable, Equatable {
    let id: String
    let title: String
    let symbol: String
    let tint: TrailRGB
    /// Sheet header while the trail is open, and the one-line pitch under it.
    let openHeadline: String
    let pitch: String
    /// Preview header before it opens, e.g. "Coming December 13".
    let comingHeadline: String
    /// "runs to January 10."
    let runsTo: String
    let start: Date
    let end: Date
    let steps: [TrailStep]
    let sizes: TrailSizes
    /// `OrbSkin` raw value and display name of the reward orb.
    let orbId: String
    let orbName: String

    func isOpen(_ now: Date) -> Bool { now >= start && now < end }
}

enum SeasonalTrails {
    static let solsticeId = "solstice_2026"
    static let binaryStarsId = "binary_stars_2027"

    /// 13 Dec 2026 16:00 UTC → 10 Jan 2027 16:00 UTC (In-App Event 6838322984).
    static let solstice = TrailEvent(
        id: solsticeId, title: "Winter Solstice Trail", symbol: "snowflake",
        tint: TrailRGB(r: 0.55, g: 0.85, b: 1.0),
        openHeadline: "The longest night is here",
        pitch: "Five winter goals. Each pays a Big Bang's worth of Cosmic Shards. Finish all five for a Challenge Star and the Frost orb, which can only be earned during the event.",
        comingHeadline: "Coming December 13", runsTo: "runs to January 10.",
        start: Date(timeIntervalSince1970: 1_797_177_600),
        end: Date(timeIntervalSince1970: 1_799_596_800),
        steps: [.dailies, .taps, .bigBangs, .generators, .bestRun],
        sizes: TrailSizes(),
        orbId: "frost", orbName: "Frost")

    /// 15 Jan 2027 08:00 UTC → 15 Feb 2027 07:00 UTC (Valentine's Day included everywhere).
    /// Twin stars: every goal comes in twos (2× the Solstice sizes, two weekly challenges).
    static let binaryStars = TrailEvent(
        id: binaryStarsId, title: "Binary Stars", symbol: "circle.circle.fill",
        tint: TrailRGB(r: 1.0, g: 0.55, b: 0.78),
        openHeadline: "Two stars, one orbit",
        pitch: "Five twin-star goals, each in twos. Each pays a Big Bang's worth of Cosmic Shards. Finish all five for a Challenge Star and the Binary orb, which can only be earned during the event.",
        comingHeadline: "Coming January 15", runsTo: "runs to February 14.",
        start: Date(timeIntervalSince1970: 1_800_000_000),
        end: Date(timeIntervalSince1970: 1_802_674_800),
        steps: [.dailies, .taps, .weeklies, .bigBangs, .bestRun],
        sizes: TrailSizes(dailies: 7, taps: 2_000, bigBangsFirst: 2, bigBangsManual: 20, bigBangsAuto: 100,
                          generatorsManual: 2_000, generatorsAuto: 50_000, weeklies: 2, bestRunFactor: 100),
        orbId: "binary", orbName: "Binary")

    static let all: [TrailEvent] = [solstice, binaryStars]

    static func event(id: String) -> TrailEvent? { all.first { $0.id == id } }
    static func open(_ now: Date) -> TrailEvent? { all.first { $0.isOpen(now) } }
    /// The next trail that hasn't started yet.
    static func upcoming(_ now: Date) -> TrailEvent? { all.filter { $0.start > now }.min { $0.start < $1.start } }
    /// What the Observatory banner shows: the open trail, else a preview of the next one.
    static func featured(_ now: Date) -> TrailEvent? { open(now) ?? upcoming(now) }

    // Shards per claimed goal, in Big Bangs (the weekly pays half of one).
    static let shardsPerStepBigBangs: Double = 1
    static let shardsPerStepFloor: Double = 50

    /// The never-reset counter a goal reads.
    static func current(_ step: TrailStep, _ s: GameState) -> Big {
        switch step {
        case .dailies:    return Big(s.totalDailyClaims)
        case .taps:       return Big(s.totalTaps)
        case .bigBangs:   return Big(s.totalBigBangs)
        case .generators: return Big(s.totalGeneratorsBought)
        case .weeklies:   return Big(s.challengeStars)
        case .bestRun:    return s.lifetimeStardust
        }
    }

    /// (baseline, target) for each of the event's goals, sized to this player now.
    static func make(_ ev: TrailEvent, _ s: GameState) -> [TrailStep: (base: Big, target: Big)] {
        let z = ev.sizes
        var out: [TrailStep: (base: Big, target: Big)] = [:]
        for step in ev.steps {
            if step == .bestRun {
                out[step] = (.zero, max(Big(1e9), s.bestRunSoFar * z.bestRunFactor))
                continue
            }
            let base = current(step, s)
            let amount: Double
            switch step {
            case .dailies:  amount = z.dailies
            case .taps:     amount = z.taps
            case .weeklies: amount = z.weeklies
            case .generators:
                amount = s.autoBuyEnabled.values.contains(true) ? z.generatorsAuto : z.generatorsManual
            case .bigBangs:
                let never = s.totalBigBangs == 0 && s.prestigeCount == 0 && s.cosmosCount == 0
                amount = never ? z.bigBangsFirst : (s.autoBigBangEnabled ? z.bigBangsAuto : z.bigBangsManual)
            case .bestRun:
                amount = 0
            }
            out[step] = (base, base + Big(amount))
        }
        return out
    }

    // MARK: - Reading a save (the running trail)

    static func target(_ step: TrailStep, _ s: GameState) -> Big { s.solsticeTargets[step.rawValue] ?? .zero }
    static func baseline(_ step: TrailStep, _ s: GameState) -> Big { s.solsticeBaselines[step.rawValue] ?? .zero }
    static func isMet(_ step: TrailStep, _ s: GameState) -> Bool { s.solsticeMet.contains(step.rawValue) }
    static func isClaimed(_ step: TrailStep, _ s: GameState) -> Bool { s.solsticeClaimed.contains(step.rawValue) }

    static func goalAmount(_ step: TrailStep, _ s: GameState) -> Big {
        step == .bestRun ? target(step, s) : target(step, s) - baseline(step, s)
    }

    static func doneAmount(_ step: TrailStep, _ s: GameState) -> Big {
        if isMet(step, s) { return goalAmount(step, s) }
        return step == .bestRun ? current(step, s) : max(current(step, s) - baseline(step, s), Big.zero)
    }

    /// 0…1. The single-run goal is on a log scale (each ×10 is an equal step).
    static func progress(_ step: TrailStep, _ s: GameState) -> Double {
        if isMet(step, s) { return 1 }
        if step == .bestRun {
            let cur = max(current(step, s), Big.one), goal = max(target(step, s), Big(10))
            return min(1, max(0, cur.log10Value / goal.log10Value))
        }
        let span = goalAmount(step, s)
        guard span > 0 else { return 1 }
        return min(1, max(0, (doneAmount(step, s) / span).double))
    }

    static func claimedCount(_ ev: TrailEvent, _ s: GameState) -> Int {
        ev.steps.filter { isClaimed($0, s) }.count
    }

    // MARK: - Copy

    static func title(_ step: TrailStep, _ s: GameState) -> String {
        let n = goalAmount(step, s)
        switch step {
        case .dailies:    return "Claim \(Formatter.count(n)) daily rewards"
        case .taps:       return "Tap the orb \(Formatter.count(n)) times"
        case .bigBangs:   return n == Big(1) ? "Your first Big Bang" : "Big Bang \(Formatter.count(n)) times"
        case .generators: return "Buy \(Formatter.count(n)) generators"
        case .weeklies:   return "Complete \(Formatter.count(n)) Weekly Challenges"
        case .bestRun:    return "Reach \(Formatter.short(n)) ✦ in one run"
        }
    }

    /// Preview line before the trail opens (sizes not set yet).
    static func previewTitle(_ step: TrailStep, _ ev: TrailEvent) -> String {
        let z = ev.sizes
        switch step {
        case .dailies:    return "Claim daily rewards on \(Int(z.dailies)) days"
        case .taps:       return "Tap the orb \(Formatter.count(z.taps)) times"
        case .bigBangs:   return "Big Bang, sized to how you play"
        case .generators: return "Buy generators, sized to how you play"
        case .weeklies:   return "Complete \(Int(z.weeklies)) Weekly Challenges"
        case .bestRun:    return "Beat your best run by ×\(Int(z.bestRunFactor))"
        }
    }
}
