import SwiftUI
import GameKit

struct SettingsView: View {
    @Environment(GameEngine.self) var engine
    @Environment(IAPManager.self) var iap
    @Environment(HapticsManager.self) var haptics
    @Environment(GameCenterManager.self) var gameCenter
    @Environment(AutomationManager.self) var automation
    @Environment(NotificationManager.self) var notif
    @State private var showResetConfirm = false
    @State private var showGameCenter = false

    var body: some View {
        NavigationStack {
            List {
                if engine.state.hasAbsoluteAscended {
                    Section {
                        HStack(spacing: 12) {
                            Image(systemName: "infinity.circle.fill")
                                .font(.title2)
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [Color(red: 1.0, green: 0.55, blue: 0.90), Color(red: 0.30, green: 0.90, blue: 1.00), Color(red: 1.0, green: 0.72, blue: 0.20)],
                                        startPoint: .leading, endPoint: .trailing
                                    )
                                )
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Absolute Observer")
                                    .font(.headline)
                                Text("You reached the end of the ladder.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }
                }

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
                    HStack {
                        Text("Automation Core")
                        Spacer()
                        Text(automationStatusLabel)
                            .foregroundStyle(automationStatusColor)
                            .monospacedDigit()
                    }
                    Button("Restore Purchases") {
                        Task { await iap.restore() }
                    }
                }

                automationSection

                notificationsSection

                tipJarSection

                Section("Support Cosmica") {
                    // Manual Rate button — bypasses the ReviewPrompter's 3/year
                    // limit by routing straight to the App Store review composer.
                    // Some users WANT to leave a review and can't find where.
                    Link(destination: URL(string: "https://apps.apple.com/app/id6784340038?action=write-review")!) {
                        HStack {
                            Image(systemName: "star.fill").foregroundStyle(.yellow)
                            Text("Rate Cosmica").foregroundStyle(.primary)
                            Spacer()
                            Image(systemName: "arrow.up.forward.square").font(.footnote).foregroundStyle(.secondary)
                        }
                    }
                    ShareLink(item: URL(string: "https://apps.apple.com/us/app/cosmica-idle-universe/id6784340038")!) {
                        HStack {
                            Image(systemName: "square.and.arrow.up").foregroundStyle(.purple)
                            Text("Share Cosmica").foregroundStyle(.primary)
                            Spacer()
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

    // v3.0 Phase 5 — Notifications. Local notifications only (no APNs).
    // Master toggle triggers the OS permission prompt the first time the player
    // flips it on. Denied state shows a link to iOS Settings — the app-store-
    // blessed way to guide users back to the toggle.
    @ViewBuilder
    private var notificationsSection: some View {
        Section {
            Toggle("Notifications", isOn: Binding(
                get: { notif.masterEnabled && notif.authorizationStatus == .authorized },
                set: { newValue in
                    if newValue {
                        // First tap ON — request the OS permission. If already
                        // authorized, this just sets the master flag. If denied
                        // at the OS level, the toggle will snap back to off and
                        // the "Open iOS Settings" link below will guide the user.
                        Task { await notif.requestPermission() }
                    } else {
                        notif.masterEnabled = false
                        notif.cancelAll()
                    }
                }
            ))
            if notif.authorizationStatus == .denied {
                Button {
                    notif.openSystemSettings()
                } label: {
                    HStack {
                        Text("Enable in iOS Settings")
                        Spacer()
                        Image(systemName: "arrow.up.forward.square")
                            .font(.footnote)
                    }
                }
            }
            if notif.masterEnabled && notif.authorizationStatus == .authorized {
                Toggle("Reactor ready", isOn: Binding(
                    get: { notif.reactorEnabled },
                    set: { notif.reactorEnabled = $0 }
                ))
                Toggle("Daily reward available", isOn: Binding(
                    get: { notif.dailyEnabled },
                    set: { notif.dailyEnabled = $0 }
                ))
                Text("Local reminders — Cosmica pings you when your reactor is ready or your daily reward is back. Nothing is sent to a server.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("Notifications")
        }
    }

    // v3.0 Phase 4 — Automation Core-gated preferences. Hidden entirely when
    // the player doesn't have automation active (no ghost UI for feature they
    // can't use).
    @ViewBuilder
    private var automationSection: some View {
        if automation.isActive {
            Section {
                Toggle("Auto-buy Cosmic Tree", isOn: Binding(
                    get: { engine.state.autoBuyCosmicTreeEnabled },
                    set: { engine.setAutoBuyCosmicTree($0) }
                ))
                Text("After each Big Bang, spends banked ◈ Cosmic Shards on the cheapest available Cosmic Tree node. Skips the Autonomy branch. Stops before dipping below 100 shards so you can still hoard for a targeted purchase.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Text("Automation")
            }
        }
    }

    // v3.0: Automation Core row status. Owned > Trial > Not owned.
    private var automationStatusLabel: String {
        if iap.automationCoreOwned { return "Owned" }
        if automation.trialActive {
            return "Trial · " + Formatter.duration(automation.trialRemaining) + " left"
        }
        return "Not owned"
    }

    private var automationStatusColor: Color {
        if iap.automationCoreOwned { return .green }
        if automation.trialActive   { return .orange }
        return .secondary
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
