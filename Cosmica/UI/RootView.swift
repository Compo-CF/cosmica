import SwiftUI

struct RootView: View {
    @Environment(GameEngine.self) private var engine
    @Environment(IAPManager.self) private var iap
    @Environment(ReviewPrompter.self) private var reviewPrompter
    @Binding var offlineSummary: OfflineAccrual.Result?
    /// True while the cold-launch splash is still on-screen. All auto-presenting
    /// sheets (offline, daily reward, tip) and full-screen covers (Absolute
    /// Ascension) gate on `!showSplash` so nothing pops over the splash.
    @Binding var showSplash: Bool
    @State private var selectedTab: Tab = .observatory
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding: Bool = false
    /// v3.0: one-shot "here's what's new" flag. Rename the key when v4.0 ships.
    @AppStorage("hasSeenWhatsNew_3_0") private var hasSeenWhatsNew_3_0: Bool = false
    @State private var showOnboarding: Bool = false
    @State private var dailyDismissed: Bool = false
    @State private var tipDismissed: Bool = false
    @State private var showTipReminder: Bool = false
    @State private var showWhatsNew: Bool = false

    enum Tab: Hashable { case observatory, upgrades, prestige, shop, settings }

    var body: some View {
        TabView(selection: $selectedTab) {
            ObservatoryView()
                .tabItem { Label("Observatory", systemImage: "scope") }
                .tag(Tab.observatory)

            UpgradesView()
                .tabItem { Label("Upgrades", systemImage: "wand.and.stars") }
                .tag(Tab.upgrades)

            BigBangView()
                .tabItem { Label("Big Bang", systemImage: "burst.fill") }
                .tag(Tab.prestige)

            ShopView()
                .tabItem { Label("Shop", systemImage: "cart") }
                .tag(Tab.shop)

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
                .tag(Tab.settings)
        }
        .tint(.purple)
        .sheet(isPresented: Binding(
            get: { !showSplash && offlineSummary != nil && (offlineSummary?.stardustEarned ?? 0) > 0 && hasSeenOnboarding },
            set: { if !$0 { offlineSummary = nil } }
        )) {
            if let summary = offlineSummary {
                OfflineWelcomeBackSheet(summary: summary) {
                    offlineSummary = nil
                }
                .presentationDetents([.medium])
            }
        }
        .sheet(isPresented: Binding(
            get: { !showSplash && engine.dailyRewardAvailable && hasSeenOnboarding && offlineSummary == nil && !dailyDismissed },
            set: { if !$0 { dailyDismissed = true } }
        )) {
            DailyRewardView { dailyDismissed = true }
                .presentationDetents([.medium])
        }
        .sheet(isPresented: $showTipReminder) {
            TipReminderView()
        }
        // Absolute Ascension — highest-priority full-screen moment. Engine flips
        // showAbsoluteCelebration the first time lifetime crosses 1e36 ✦; the sheet
        // acknowledges it (which persists a "shown" flag so it never re-fires).
        .fullScreenCover(isPresented: Binding(
            get: { !showSplash && engine.showAbsoluteCelebration },
            set: { if !$0 { engine.acknowledgeAscension() } }
        )) {
            AbsoluteAscensionView()
        }
        .fullScreenCover(isPresented: $showOnboarding) {
            OnboardingView()
        }
        // v3.0: one-shot "What's New" sheet for players upgrading from v2.x.
        // Brand new installs skip because prestigeCount/lifetimeStardust are 0
        // and hasSeenWhatsNew_3_0 will get seeded when they finish onboarding
        // (see the .onChange below).
        .sheet(isPresented: $showWhatsNew) {
            WhatsNewSheet {
                hasSeenWhatsNew_3_0 = true
                showWhatsNew = false
            }
        }
        .onAppear {
            if !hasSeenOnboarding { showOnboarding = true }
        }
        // Fire the What's New once splash + onboarding are out of the way, and
        // only for players who had prior progress (upgrade path, not new install).
        .onChange(of: showSplash) { _, isSplash in
            guard !isSplash else { return }
            maybeShowWhatsNew()
        }
        // Also seed the flag when a brand-new install finishes onboarding, so
        // they don't get the v3.0 popup on their SECOND launch.
        .onChange(of: hasSeenOnboarding) { _, done in
            if done, !hasSeenWhatsNew_3_0,
               engine.state.prestigeCount == 0,
               engine.state.lifetimeStardust == 0 {
                hasSeenWhatsNew_3_0 = true
            }
        }
        // v2.1: achievement-burst rating trigger. Fires when a play session pushes
        // total unlocked achievements across a multiple of 5. ReviewPrompter's 30-day
        // floor keeps this from ever feeling spammy.
        .onChange(of: engine.state.unlockedAchievementIds.count) { oldValue, newValue in
            guard newValue > oldValue, newValue > 0, newValue % 5 == 0 else { return }
            reviewPrompter.maybePrompt(reason: "achievement_burst_\(newValue)")
        }
        // v2.1: view-layer tip trigger. First True Cosmos and first Wonder built
        // both set pendingTipTrigger; here we honor it if the "big moment" gate
        // agrees (opt-out, hasEverTipped, products loaded, past 7-day grace).
        .onChange(of: iap.pendingTipTrigger) { _, newValue in
            guard newValue else { return }
            iap.pendingTipTrigger = false   // consume regardless of eligibility
            guard iap.tipReminderEligibleForBigMoment else { return }
            iap.recordTipPromptShown()
            tipDismissed = false
            showTipReminder = true
        }
        // v3.0 WhatsNew fires after splash on the first cold launch of the
        // upgraded build for any player with prior progress. Never on brand
        // new installs (see .onChange(hasSeenOnboarding) above).
        .task {
            try? await Task.sleep(nanoseconds: 800_000_000)
            maybeShowWhatsNew()
        }
        // Fire the gentle tip reminder at most once per cold launch, after any
        // higher-priority sheet has had its chance (onboarding, offline sheet,
        // daily reward). Gating lives in IAPManager.tipReminderEligible; we
        // just wait until the moment is right and stamp the last-shown clock.
        .task {
            // Give products a moment to load before we consult eligibility.
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            guard hasSeenOnboarding,
                  offlineSummary == nil,
                  !engine.dailyRewardAvailable,
                  !tipDismissed,
                  iap.tipReminderEligible
            else { return }
            iap.recordTipPromptShown()
            showTipReminder = true
            tipDismissed = true
        }
    }

    /// Fire the v3.0 WhatsNew sheet at most once per install. Guards on:
    /// splash gone, onboarding done, hasn't seen it, has actual prior progress
    /// (avoids showing to brand-new installs that haven't touched anything yet).
    private func maybeShowWhatsNew() {
        guard !showSplash,
              hasSeenOnboarding,
              !hasSeenWhatsNew_3_0,
              (engine.state.prestigeCount > 0 || engine.state.lifetimeStardust > 0),
              !showOnboarding,
              !showTipReminder,
              offlineSummary == nil,
              !engine.showAbsoluteCelebration
        else { return }
        showWhatsNew = true
    }
}

struct OfflineWelcomeBackSheet: View {
    let summary: OfflineAccrual.Result
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "moon.stars.fill")
                .font(.system(size: 60))
                .foregroundStyle(.purple)
                .padding(.top, 20)

            Text("Welcome back, observer")
                .font(.title2.bold())

            Text("While you were away (\(Formatter.duration(summary.secondsCounted)))")
                .foregroundStyle(.secondary)

            Text("+\(Formatter.short(summary.stardustEarned)) ✦")
                .font(.system(size: 48, weight: .heavy, design: .rounded))
                .foregroundStyle(LinearGradient(colors: [.purple, .blue], startPoint: .leading, endPoint: .trailing))

            if summary.wasCapped {
                Text("Capped at \(Formatter.duration(summary.capUsed)) — watch a rewarded ad in the Shop to extend offline earnings to 24h.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            Spacer()

            Button(action: onDismiss) {
                Text("Continue")
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .background(.purple, in: RoundedRectangle(cornerRadius: 14))
                    .foregroundStyle(.white)
            }
            .padding(.horizontal)
            .padding(.bottom, 24)
        }
    }
}
