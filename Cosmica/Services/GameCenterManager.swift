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

    func report(state: GameState) async {
        guard isAuthenticated else { return }

        // Clamp lifetime stardust to leaderboard int range.
        let lifetime = Int(min(state.lifetimeStardust, Double(Int.max)))
        await submit(score: lifetime,             leaderboard: Self.leaderboardLifetimeStardust)
        await submit(score: state.prestigeCount,  leaderboard: Self.leaderboardPrestigeCount)
        await submit(score: state.currentTier.rawValue, leaderboard: Self.leaderboardTier)
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
