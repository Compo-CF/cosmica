import SwiftUI
import AppTrackingTransparency

@main
struct CosmicaApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @Environment(\.scenePhase) private var scenePhase

    @State private var engine: GameEngine
    @State private var ads = AdManager()
    @State private var iap = IAPManager()
    @State private var haptics = HapticsManager()
    @State private var sound = SoundManager()
    @State private var gameCenter = GameCenterManager()
    @State private var cloud = CloudSync.shared
    @State private var offlineSummary: OfflineAccrual.Result?
    @State private var showSplash = true
    @State private var reviewPrompter = ReviewPrompter()
    @State private var automation = AutomationManager()
    @State private var notif = NotificationManager()
    /// v3.1.2 — Google consent (EEA/UK/CH) → ATT → Mobile Ads, in that order.
    @State private var consent = ConsentManager()
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding: Bool = false
    /// v3.0.2 — true once this device has successfully consulted iCloud (account
    /// available + pull returned). Uploads are blocked until then, so a fresh
    /// install can never push its empty save over the player's real cloud copy.
    @State private var cloudChecked = false

    init() {
        let persistence = (try? Persistence()) ?? Persistence.inMemory()
        let initial = persistence.load()
        _engine = State(initialValue: GameEngine(state: initial, persistence: persistence))
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                RootView(offlineSummary: $offlineSummary, showSplash: $showSplash)
                    .environment(engine)
                    .environment(ads)
                    .environment(iap)
                    .environment(haptics)
                    .environment(sound)
                    .environment(gameCenter)
                    .environment(reviewPrompter)
                    .environment(automation)
                    .environment(notif)
                    .environment(consent)
                if showSplash {
                    SplashView()
                        .transition(.opacity)
                        .zIndex(1)
                }
            }
            .preferredColorScheme(.dark)
            .task {
                // Cold-launch splash. Long enough for the Big Bang animation to
                // settle (v3.0.5), short enough to stay out of the way. Only fires
                // on the first mount per launch.
                try? await Task.sleep(nanoseconds: 1_700_000_000)
                withAnimation(.easeInOut(duration: 0.45)) { showSplash = false }
            }
            .task {
                    // v3.2 — sound effects ride on the haptics calls; music pauses for ads.
                    haptics.sound = sound
                    ads.onFullScreenAd = { showing in sound.setAdShowing(showing) }
                    sound.start()
                    await iap.start()
                    ads.configure(removeAdsOwned: iap.removeAdsOwned)
                    // v3.3 — StoreKit decides; this also clears it after a refund.
                    // Before applyOffline below, so offline earnings use the right rate.
                    engine.state.doublerOwned = iap.doublerOwned
                    // v3.0: wire the automation façade once both services exist.
                    // Refs are set once and never rebound (App @State holds strong).
                    // The engine.automation back-ref is `weak` — no cycle.
                    automation.iap = iap
                    automation.engine = engine
                    engine.automation = automation
                    // v3.0 Phase 5 — notification manager needs to install its
                    // delegate before the OS may deliver a tap event on cold launch.
                    notif.start()
                    gameCenter.authenticate()
                    offlineSummary = engine.applyOffline()
                    engine.start()
                    await syncFromCloud()

                    // v3.1.2 — consent → ATT → ads. Players who've finished onboarding
                    // run it here, once the main UI has settled and no modal is up
                    // (same timing the old ATT fallback used). New installs run it when
                    // onboarding finishes (onChange below), so nothing stacks on the cover.
                    try? await Task.sleep(nanoseconds: 1_500_000_000)
                    if hasSeenOnboarding {
                        await startAdsFlow()
                    }
                }
            .onChange(of: hasSeenOnboarding) { _, done in
                if done { Task { await startAdsFlow() } }
            }
            // v3.0.3 — widget tap (cosmica://observatory). Reuses the notification
            // deep-link path; RootView switches tabs and clears it.
            .onOpenURL { url in
                guard url.scheme == "cosmica", url.host == "observatory" else { return }
                notif.pendingTab = .observatory
            }
            .onChange(of: iap.removeAdsOwned) { _, owned in
                ads.configure(removeAdsOwned: owned)
                engine.state.removeAdsOwned = owned
            }
            .onChange(of: iap.doublerOwned) { _, owned in
                engine.state.doublerOwned = owned
                engine.save()
            }
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .background, .inactive:
                if phase == .background { sound.suspend() }
                engine.save()
                // v3.0.3 — offline accrual starts now; hand the widget its baseline.
                // Background only: .inactive also fires for Control Center pulls,
                // and each publish costs a widget reload.
                if phase == .background { WidgetSnapshotWriter.publish(engine.state) }
                pushToCloud()
                Task { await gameCenter.report(state: engine.state) }
                // v3.0 Phase 5 — schedule "reactor ready" + "daily reward"
                // notifications for while the app is closed. No-op unless the
                // player has opted in AND the OS has granted permission.
                notif.scheduleAll(engine: engine)
            case .active:
                sound.resume()
                engine.start()
                // Coming back — nothing to remind them about now that they're here.
                notif.cancelAll()
                // User may have toggled our permission in iOS Settings while away.
                Task { await notif.refreshAuthorizationStatus() }
                // v3.0.2 — pull on every foreground, not just cold launch. Catches
                // (a) iCloud not being ready yet on a freshly set-up phone, and
                // (b) progress made on another device since we last looked.
                Task { await syncFromCloud() }
            @unknown default:
                break
            }
        }
    }

    /// v3.1.2 — Google's required order: consent form (only where regulations apply), then
    /// Apple's ATT prompt (asked once), then start the Mobile Ads SDK only if consent allows.
    /// Safe to call repeatedly: the form shows only when needed, ATT asks once, ads start once.
    @MainActor
    private func startAdsFlow() async {
        await consent.gather()
        await consent.requestTrackingIfNeeded()
        if consent.canRequestAds {
            ads.startAfterConsent(removeAdsOwned: iap.removeAdsOwned)
        }
    }

    /// v3.0.2 — adopt the iCloud save when it holds more lasting progress than
    /// this device (see `GameState.progressRank`). Safe to call repeatedly.
    private func syncFromCloud() async {
        guard await cloud.accountAvailable() else { return }   // retry next foreground
        do {
            if let remote = try await cloud.pull(), remote.isAhead(of: engine.state) {
                engine.state = remote
                engine.state.doublerOwned = iap.doublerOwned   // v3.3 — ownership is per Apple ID, not per save
                engine.save()
                // Credit the time since that save was last active on the other device.
                offlineSummary = engine.applyOffline()
            }
            cloudChecked = true
        } catch {
            // CloudKit / network hiccup — leave cloudChecked false and retry on the
            // next foreground. Never push while we haven't seen the cloud copy.
        }
    }

    /// v3.0.2 — upload on background, guarded two ways:
    ///   1. Skipped until this device has checked iCloud at least once.
    ///   2. Wrapped in a background task so iOS doesn't suspend us mid-upload.
    /// If iCloud turns out to hold MORE progress, push() refuses to overwrite it
    /// and we adopt that save locally instead.
    private func pushToCloud() {
        guard cloudChecked else { return }
        let snapshot = engine.state
        let bgTask = UIApplication.shared.beginBackgroundTask(withName: "cosmica.cloudPush")
        Task {
            defer { UIApplication.shared.endBackgroundTask(bgTask) }
            if case .remoteAhead(let remote)? = try? await cloud.push(state: snapshot) {
                engine.state = remote
                engine.state.doublerOwned = iap.doublerOwned
                engine.save()
                WidgetSnapshotWriter.publish(engine.state)
            }
        }
    }
}
