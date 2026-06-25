import SwiftUI
import GameKit

struct SettingsView: View {
    @Environment(GameEngine.self) var engine
    @Environment(IAPManager.self) var iap
    @Environment(GameCenterManager.self) var gameCenter
    @State private var showResetConfirm = false
    @State private var showGameCenter = false

    var body: some View {
        NavigationStack {
            List {
                Section("Stats") {
                    statRow("Stardust", Formatter.short(engine.state.stardust) + " ✦")
                    statRow("Lifetime Stardust", Formatter.short(engine.state.lifetimeStardust) + " ✦")
                    statRow("Cosmic Shards", Formatter.short(engine.state.cosmicShards) + " ◈")
                    statRow("Prestiges", "\(engine.state.prestigeCount)")
                    statRow("Total Taps", "\(engine.state.totalTaps)")
                    statRow("Current Tier", engine.state.currentTier.title)
                    statRow("Earnings / sec", Formatter.short(engine.state.stardustPerSecond) + " ✦/s")
                }

                Section("Game Center") {
                    Button("Open Leaderboards & Achievements") {
                        showGameCenter = true
                    }
                }

                Section("Purchases") {
                    HStack {
                        Text("Remove Ads")
                        Spacer()
                        Text(iap.removeAdsOwned ? "Owned" : "Not owned")
                            .foregroundStyle(iap.removeAdsOwned ? .green : .secondary)
                    }
                    Button("Restore Purchases") {
                        Task { await iap.restore() }
                    }
                }

                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                            .foregroundStyle(.secondary)
                    }
                    Link("Privacy Policy", destination: URL(string: "https://centricfiber.com/cosmica/privacy")!)
                    Link("Terms of Service", destination: URL(string: "https://centricfiber.com/cosmica/terms")!)
                }

                Section("Danger Zone") {
                    Button("Reset Game", role: .destructive) {
                        showResetConfirm = true
                    }
                }
            }
            .navigationTitle("Settings")
            .confirmationDialog(
                "Reset all progress?",
                isPresented: $showResetConfirm,
                titleVisibility: .visible
            ) {
                Button("Reset Everything", role: .destructive) {
                    engine.state = GameState()
                    engine.save()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This wipes local progress. CloudKit may sync the cloud save back on next launch.")
            }
            .sheet(isPresented: $showGameCenter) {
                GameCenterDashboard()
                    .ignoresSafeArea()
            }
        }
    }

    private func statRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(value).foregroundStyle(.secondary).monospacedDigit()
        }
    }
}

/// SwiftUI bridge for GameKit's GKGameCenterViewController.
struct GameCenterDashboard: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> GKGameCenterViewController {
        let vc = GKGameCenterViewController(state: .dashboard)
        vc.gameCenterDelegate = context.coordinator
        return vc
    }
    func updateUIViewController(_ uiViewController: GKGameCenterViewController, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator() }
    final class Coordinator: NSObject, GKGameCenterControllerDelegate {
        func gameCenterViewControllerDidFinish(_ gameCenterViewController: GKGameCenterViewController) {
            gameCenterViewController.dismiss(animated: true)
        }
    }
}
