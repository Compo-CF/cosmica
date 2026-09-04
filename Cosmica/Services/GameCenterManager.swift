import Foundation
import Observation
import GameKit

/// Wraps Game Center authentication and leaderboard submission.
///
/// Leaderboard IDs must match what you configure in App Store Connect.
@MainActor
@Observable
final class GameCenterManager {
    static let leaderboardLifetimeStardust = "cosmica.lifetime_stardust"
    static let leaderboardPrestigeCount    = "cosmica.prestige_count"
    static let leaderboardTier             = "cosmica.tier"

    private(set) var isAuthenticated = false

    func authenticate() {
        GKLocalPlayer.local.authenticateHandler = { [weak self] viewController, error in
            if let error {
                print("[GameCenter] Auth failed: \(error.localizedDescription)")
                self?.isAuthenticated = false
                return
            }
            if viewController == nil {
                self?.isAuthenticated = GKLocalPlayer.local.isAuthenticated
            }
        }
    }

    /// Largest `Double` that is guaranteed to round-trip through `Int` without
    /// trapping. `Double(Int.max)` itself is one bit *above* `Int.max` (2^63) —
    /// Double only has 53 mantissa bits, so `Int.max` (2^63 - 1) rounds up when
    /// cast — so we use `.nextDown` to step to the largest safely-representable
    /// value. In practice this is Int.max minus ~1024. Fine for a leaderboard.
    private static let leaderboardSafeMax: Double = Double(Int.max).nextDown

    /// Non-trapping Double→Int for values that may have grown unbounded across
    /// prestige cycles (lifetime stardust for a Cosmica-late player is easily > 1e18).
    /// Returns 0 for NaN / non-positive values and clamps at `leaderboardSafeMax`.
    private static func clampedScore(_ d: Double) -> Int {
        guard d.isFinite, d > 0 else { return 0 }
        return Int(min(d, leaderboardSafeMax))
    }

    func report(state: GameState) async {
        guard isAuthenticated else { return }
        await submit(score: Self.clampedScore(state.lifetimeStardust), leaderboard: Self.leaderboardLifetimeStardust)
        await submit(score: state.prestigeCount,                       leaderboard: Self.leaderboardPrestigeCount)
        await submit(score: state.currentTier.rawValue,                leaderboard: Self.leaderboardTier)
    }

    private func submit(score: Int, leaderboard: String) async {
        do {
            try await GKLeaderboard.submitScore(
                score,
                context: 0,
                player: GKLocalPlayer.local,
                leaderboardIDs: [leaderboard]
            )
        } catch {
            print("[GameCenter] Submit failed for \(leaderboard): \(error.localizedDescription)")
        }
    }
}
