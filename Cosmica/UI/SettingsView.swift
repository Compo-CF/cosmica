import SwiftUI
import GameKit

/// The Support section opens `https://ko-fi.com/<handle>` in the system browser.
/// KEPT EMPTY for App Store builds — Apple guideline 3.1.1 requires all donation
/// mechanisms for a developer's own app to go through IAP so Apple takes its cut.
/// Ko-fi links referencing the app or the developer are rejected.
/// v1.1 plan: replace with an IAP-based "Tip Jar" (small/medium/large consumables).
private let kofiUsername: String = ""

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

                if !kofiUsername.isEmpty {
                    Section("Support the Developer") {
                        if let url = URL(string: "https://ko-fi.com/\(kofiUsername)") {
                            Link(destination: url) {
                                HStack(spacing: 12) {
                                    Image(systemName: "cup.and.saucer.fill")
                                        .foregroundStyle(.orange)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Buy me a coffee on Ko-fi")
                                            .foregroundStyle(.primary)
                                        Text("Cosmica is built solo — tips help me ship the next update.")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }
                }

                Section("Legal") {
                    NavigationLink("Privacy Policy") {
                        PrivacyPolicyView()
                    }
                    NavigationLink("Terms of Service") {
                        TermsOfServiceView()
                    }
                }

                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("Developer")
                        Spacer()
                        Text("Anthony Compofelice").foregroundStyle(.secondary)
                    }
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
