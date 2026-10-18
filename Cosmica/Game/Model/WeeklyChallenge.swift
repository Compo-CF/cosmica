import Foundation

/// v3.2 — the Weekly Cosmic Challenge: one goal per week, rotating by week
/// number, sized to the player's own progress so it's a real target for a
/// day-one player and for someone on their 50th True Cosmos alike.
///
/// Goals are measured as deltas on lifetime counters that never reset (see
/// `GameState.totalBigBangs` etc.), so nothing about how the game plays
/// changes and a Big Bang mid-week never erases progress. Single-run goals
/// latch `challengeCompleted` the moment they're met for the same reason.
///
/// Reward: a Challenge Star (+10% earnings, permanent, never reset) plus
/// half a Big Bang's worth of Cosmic Shards. An unclaimed reward is granted
/// automatically when the week rolls over, so nothing earned is lost.
enum ChallengeKind: String, CaseIterable {
    case bigBangs, beatBestRun, taps, generators, dailyRewards, trueCosmos
}

struct WeeklyChallenge: Equatable {
    let week: Int
    let kind: ChallengeKind
    /// Counter value when the week began (0 for single-run goals).
    let baseline: Double
    /// Counter value that completes the goal.
    let target: Double

    /// Permanent earnings per Challenge Star, additive (10 stars = ×2).
    static let starBonus = 0.10

    /// Weeks run Monday 00:00 UTC to Monday 00:00 UTC, counted from Monday
    /// 5 Jan 2026 — the same week boundary for every player everywhere.
    static let epoch = Date(timeIntervalSince1970: 1_767_571_200)
    static let weekLength: TimeInterval = 7 * 86_400

    static func week(for date: Date) -> Int {
        Int((date.timeIntervalSince(epoch) / weekLength).rounded(.down))
    }

    static func weekEnd(_ week: Int) -> Date {
        epoch.addingTimeInterval(Double(week + 1) * weekLength)
    }

    /// Goals that make sense for this player. True Cosmos joins the rotation
    /// once they've collapsed at least one cosmos.
    static func pool(for state: GameState) -> [ChallengeKind] {
        var kinds: [ChallengeKind] = [.bigBangs, .beatBestRun, .taps, .generators, .dailyRewards]
        if state.cosmosCount >= 1 { kinds.append(.trueCosmos) }
        return kinds
    }

    /// This week's challenge for this player, sized to where they are now.
    static func make(week: Int, state: GameState, now: Date) -> WeeklyChallenge {
        let kinds = pool(for: state)
        let n = kinds.count
        let kind = kinds[((week % n) + n) % n]
        switch kind {
        case .bigBangs:
            let neverBanged = state.totalBigBangs == 0 && state.prestigeCount == 0 && state.cosmosCount == 0
            let count: Double = neverBanged ? 1 : (state.autoBigBangEnabled ? 25 : 5)
            let base = Double(state.totalBigBangs)
            return WeeklyChallenge(week: week, kind: kind, baseline: base, target: base + count)
        case .beatBestRun:
            let target = max(1e9, state.bestRunSoFar * 10)
            return WeeklyChallenge(week: week, kind: kind, baseline: 0, target: target.isFinite ? target : 1e300)
        case .taps:
            let base = Double(state.totalTaps)
            return WeeklyChallenge(week: week, kind: kind, baseline: base, target: base + 1_000)
        case .generators:
            let auto = state.autoBuyEnabled.values.contains(true)
            let base = state.totalGeneratorsBought
            return WeeklyChallenge(week: week, kind: kind, baseline: base, target: base + (auto ? 10_000 : 500))
        case .dailyRewards:
            // Never ask for more days than the week has left (a player who
            // first opens 3.2 on a Saturday gets 2, not 5).
            let daysLeft = max(1, Int((weekEnd(week).timeIntervalSince(now) / 86_400).rounded(.up)))
            let base = Double(state.totalDailyClaims)
            return WeeklyChallenge(week: week, kind: kind, baseline: base, target: base + Double(min(5, daysLeft)))
        case .trueCosmos:
            let base = Double(state.cosmosCount)
            return WeeklyChallenge(week: week, kind: kind, baseline: base, target: base + 1)
        }
    }

    /// Rebuild the stored challenge from the save, or nil if none is set.
    static func stored(in state: GameState) -> WeeklyChallenge? {
        guard state.challengeWeek >= 0, let kind = ChallengeKind(rawValue: state.challengeKindRaw) else { return nil }
        return WeeklyChallenge(week: state.challengeWeek, kind: kind,
                               baseline: state.challengeBaseline, target: state.challengeTarget)
    }

    // MARK: - Measuring

    /// The counter this goal reads.
    func current(_ state: GameState) -> Double {
        switch kind {
        case .bigBangs:     return Double(state.totalBigBangs)
        case .beatBestRun:  return state.lifetimeStardust
        case .taps:         return Double(state.totalTaps)
        case .generators:   return state.totalGeneratorsBought
        case .dailyRewards: return Double(state.totalDailyClaims)
        case .trueCosmos:   return Double(state.cosmosCount)
        }
    }

    func isMet(_ state: GameState) -> Bool { current(state) >= target }

    /// 0…1 for the progress bar. The single-run goal uses a log scale (the
    /// same reasoning as the tier bar: each ×10 is an equal step of effort).
    func progress(_ state: GameState) -> Double {
        if kind == .beatBestRun {
            let cur = max(1, current(state)), goal = max(10, target)
            return min(1, max(0, log10(cur) / log10(goal)))
        }
        let span = target - baseline
        guard span > 0 else { return 1 }
        return min(1, max(0, (current(state) - baseline) / span))
    }

    /// How much of the goal is done, in the goal's own units.
    func doneAmount(_ state: GameState) -> Double {
        kind == .beatBestRun ? current(state) : max(0, current(state) - baseline)
    }

    var goalAmount: Double { kind == .beatBestRun ? target : target - baseline }

    // MARK: - Copy

    var title: String {
        switch kind {
        case .bigBangs:     return goalAmount == 1 ? "Your first Big Bang" : "Big Bang \(Formatter.count(goalAmount)) times"
        case .beatBestRun:  return "Beat your best run"
        case .taps:         return "Tap the orb \(Formatter.count(goalAmount)) times"
        case .generators:   return "Buy \(Formatter.count(goalAmount)) generators"
        case .dailyRewards: return "Claim \(Formatter.count(goalAmount)) daily rewards"
        case .trueCosmos:   return "Collapse a cosmos"
        }
    }

    var detail: String {
        switch kind {
        case .bigBangs:     return "Any Big Bang counts, manual or automatic."
        case .beatBestRun:  return "Reach \(Formatter.short(target)) ✦ in a single run."
        case .taps:         return "Every tap on the Observatory orb counts."
        case .generators:   return "Auto-buy counts too."
        case .dailyRewards: return "Come back on different days this week."
        case .trueCosmos:   return "Complete a True Cosmos before the week ends."
        }
    }

    var symbol: String {
        switch kind {
        case .bigBangs:     return "burst.fill"
        case .beatBestRun:  return "chart.line.uptrend.xyaxis"
        case .taps:         return "hand.tap.fill"
        case .generators:   return "scope"
        case .dailyRewards: return "calendar"
        case .trueCosmos:   return "infinity.circle.fill"
        }
    }
}
