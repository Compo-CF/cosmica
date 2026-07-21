import SwiftUI
import GameKit

struct SettingsView: View {
    @Environment(GameEngine.self) var engine
    @Environment(IAPManager.self) var iap
    @Environment(HapticsManager.self) var haptics
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

                tipJarSection

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
                        Text(versionString).foregroundStyle(.secondary).monospacedDigit()
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
            .alert("Thank you! 🙏", isPresented: Binding(
                get: { iap.didTip },
                set: { if !$0 { iap.didTip = false } }
            )) {
                Button("You're welcome", role: .cancel) { iap.didTip = false }
            } message: {
                Text("Your tip genuinely helps keep Cosmica free and shipping updates. It means a lot.")
            }
        }
    }

    // MARK: - Tip jar (always-accessible)

    /// v1.2: in-app tip jar (StoreKit consumables). Hidden until products load so
    /// there are never dead buttons. Labels map small → generous; the amount comes
    /// from StoreKit's localized price, never hard-coded. Matches S-Tier Eats'
    /// AboutSheetView pattern.
    @ViewBuilder
    private var tipJarSection: some View {
        let tips = iap.tipProducts
        if !tips.isEmpty {
            Section {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Cosmica is free. If it's earned a spot in your day, a tip helps keep it going — no pressure.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 10) {
                        ForEach(Array(tips.enumerated()), id: \.element.id) { idx, product in
                            Button {
                                Task {
                                    let ok = await iap.purchaseTip(product)
                                    if ok { haptics.upgrade() }
                                }
                            } label: {
                                VStack(spacing: 3) {
                                    Text(tipLabel(idx))
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.secondary)
                                    Text(product.displayPrice)
                                        .font(.subheadline.bold())
                                        .foregroundStyle(.primary)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
                            }
                            .buttonStyle(.plain)
                            .disabled(iap.purchaseInFlight)
                        }
                    }
                }
                .padding(.vertical, 4)
            } header: {
                Text("Leave a tip")
            }
        }
    }

    private func tipLabel(_ idx: Int) -> String {
        ["Small tip", "Medium tip", "Generous tip"][min(idx, 2)]
    }

    private var versionString: String {
        let dict = Bundle.main.infoDictionary
        let v = dict?["CFBundleShortVersionString"] as? String ?? "—"
        let b = dict?["CFBundleVersion"] as? String ?? "—"
        return "\(v) (\(b))"
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
