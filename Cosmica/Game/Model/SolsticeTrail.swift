import Foundation

/// v4.0.4 — the Winter Solstice Trail: a time-limited event (13 Dec 2026 16:00 UTC to
/// 10 Jan 2027 16:00 UTC, the dates of the App Store In-App Event). Five goals, set
/// the first time the player opens the game inside the window and sized to their own
/// progress (same rules as the Weekly Challenge, scaled up for four weeks).
///
/// Each goal pays one Big Bang's worth of Cosmic Shards when claimed. Claiming all
/// five pays a Challenge Star (+10% earnings, forever) and the Frost orb, which can
/// only be earned during the event and is kept for good. Goals met but not claimed
/// when the window closes are paid automatically, so nothing earned is lost.
///
/// Goals read the never-reset lifetime counters, so a Big Bang never erases progress;
/// the single-run goal latches the moment it's met.
enum SolsticeStep: String, CaseIterable, Identifiable {
    case dailies, taps, bigBangs, generators, bestRun

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .dailies:    return "calendar"
        case .taps:       return "hand.tap.fill"
        case .bigBangs:   return "burst.fill"
        case .generators: return "scope"
        case .bestRun:    return "chart.line.uptrend.xyaxis"
        }
    }
}

enum SolsticeTrail {
    static let eventId = "solstice_2026"
    /// 13 Dec 2026 16:00 UTC.
    static let start = Date(timeIntervalSince1970: 1_797_177_600)
    /// 10 Jan 2027 16:00 UTC.
    static let end = Date(timeIntervalSince1970: 1_799_596_800)

    static func isOpen(_ now: Date) -> Bool { now >= start && now < end }
    static func isUpcoming(_ now: Date) -> Bool { now < start }

    // Goal sizes (see `make`).
    static let dailyClaims: Double = 5
    static let taps: Double = 2_500
    static let generatorsManual: Double = 1_000
    static let generatorsAuto: Double = 25_000
    static let bigBangsFirst: Double = 1
    static let bigBangsManual: Double = 10
    static let bigBangsAuto: Double = 50
    /// The single-run goal: ×100 the best run so far (the weekly asks ×10), min 1e9.
    static let bestRunFactor: Double = 100

    /// Shards per claimed goal, in Big Bangs (the weekly pays half of one).
    static let shardsPerStepBigBangs: Double = 1
    static let shardsPerStepFloor: Double = 50

    /// The never-reset counter a goal reads.
    static func current(_ step: SolsticeStep, _ s: GameState) -> Big {
        switch step {
        case .dailies:    return Big(s.totalDailyClaims)
        case .taps:       return Big(s.totalTaps)
        case .bigBangs:   return Big(s.totalBigBangs)
        case .generators: return Big(s.totalGeneratorsBought)
        case .bestRun:    return s.lifetimeStardust
        }
    }

    /// (baseline, target) for each goal, sized to this player now.
    static func make(_ s: GameState) -> [SolsticeStep: (base: Big, target: Big)] {
        var out: [SolsticeStep: (base: Big, target: Big)] = [:]
        for step in SolsticeStep.allCases {
            if step == .bestRun {
                out[step] = (.zero, max(Big(1e9), s.bestRunSoFar * bestRunFactor))
                continue
            }
            let base = current(step, s)
            let amount: Double
            switch step {
            case .dailies:  amount = dailyClaims
            case .taps:     amount = taps
            case .generators:
                amount = s.autoBuyEnabled.values.contains(true) ? generatorsAuto : generatorsManual
            case .bigBangs:
                let never = s.totalBigBangs == 0 && s.prestigeCount == 0 && s.cosmosCount == 0
                amount = never ? bigBangsFirst : (s.autoBigBangEnabled ? bigBangsAuto : bigBangsManual)
            case .bestRun:
                amount = 0
            }
            out[step] = (base, base + Big(amount))
        }
        return out
    }

    // MARK: - Reading a save

    static func target(_ step: SolsticeStep, _ s: GameState) -> Big { s.solsticeTargets[step.rawValue] ?? .zero }
    static func baseline(_ step: SolsticeStep, _ s: GameState) -> Big { s.solsticeBaselines[step.rawValue] ?? .zero }
    static func isMet(_ step: SolsticeStep, _ s: GameState) -> Bool { s.solsticeMet.contains(step.rawValue) }
    static func isClaimed(_ step: SolsticeStep, _ s: GameState) -> Bool { s.solsticeClaimed.contains(step.rawValue) }

    static func goalAmount(_ step: SolsticeStep, _ s: GameState) -> Big {
        step == .bestRun ? target(step, s) : target(step, s) - baseline(step, s)
    }

    static func doneAmount(_ step: SolsticeStep, _ s: GameState) -> Big {
        if isMet(step, s) { return goalAmount(step, s) }
        return step == .bestRun ? current(step, s) : max(current(step, s) - baseline(step, s), Big.zero)
    }

    /// 0…1. The single-run goal is on a log scale (each ×10 is an equal step).
    static func progress(_ step: SolsticeStep, _ s: GameState) -> Double {
        if isMet(step, s) { return 1 }
        if step == .bestRun {
            let cur = max(current(step, s), Big.one), goal = max(target(step, s), Big(10))
            return min(1, max(0, cur.log10Value / goal.log10Value))
        }
        let span = goalAmount(step, s)
        guard span > 0 else { return 1 }
        return min(1, max(0, (doneAmount(step, s) / span).double))
    }

    static func claimedCount(_ s: GameState) -> Int {
        SolsticeStep.allCases.filter { isClaimed($0, s) }.count
    }

    // MARK: - Copy

    static func title(_ step: SolsticeStep, _ s: GameState) -> String {
        let n = goalAmount(step, s)
        switch step {
        case .dailies:    return "Claim \(Formatter.count(n)) daily rewards"
        case .taps:       return "Tap the orb \(Formatter.count(n)) times"
        case .bigBangs:   return n == Big(1) ? "Your first Big Bang" : "Big Bang \(Formatter.count(n)) times"
        case .generators: return "Buy \(Formatter.count(n)) generators"
        case .bestRun:    return "Reach \(Formatter.short(n)) ✦ in one run"
        }
    }
}
