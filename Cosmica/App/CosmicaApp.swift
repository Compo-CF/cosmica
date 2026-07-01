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
    @State private var gameCenter = GameCenterManager()
    @State private var cloud = CloudSync()
    @State private var offlineSummary: OfflineAccrual.Result?

    init() {
        let persistence = (try? Persistence()) ?? Persistence.inMemory()
        let initial = persistence.load()
        _engine = State(initialValue: GameEngine(state: initial, persistence: persistence))
    }

    var body: some Scene {
        WindowGroup {
            RootView(offlineSummary: $offlineSummary)
                .environment(engine)
                .environment(ads)
                .environment(iap)
                .environment(haptics)
                .environment(gameCenter)
                .preferredColorScheme(.dark)
                .task {
                    // ATT prompt must run before AdMob starts serving personalized
                    // ads so the user's choice is respected. Small delay lets the
                    // launch UI settle so the prompt doesn't feel jarring.
                    try? await Task.sleep(nanoseconds: 800_000_000)
                    await requestTrackingPermissionIfNeeded()

                    await iap.start()
                    ads.configure(removeAdsOwned: iap.removeAdsOwned)
                    gameCenter.authenticate()
                    offlineSummary = engine.applyOffline()
                    engine.start()
                    await syncFromCloudIfNeeded()
                }
                .onChange(of: iap.removeAdsOwned) { _, owned in
                    ads.configure(removeAdsOwned: owned)
                    engine.state.removeAdsOwned = owned
                }
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .background, .inactive:
                engine.save()
                Task { try? await cloud.push(state: engine.state) }
                Task { await gameCenter.report(state: engine.state) }
            case .active:
                engine.start()
            @unknown default:
                break
            }
        }
    }

    private func requestTrackingPermissionIfNeeded() async {
        // Only request on the first launch after install / after user resets tracking.
        // Subsequent statuses (.authorized / .denied / .restricted) mean the user has
        // already answered and we must not prompt again.
        guard ATTrackingManager.trackingAuthorizationStatus == .notDetermined else { return }
        _ = await ATTrackingManager.requestTrackingAuthorization()
    }

    private func syncFromCloudIfNeeded() async {
        guard let remote = try? await cloud.pull() else { return }
        let reconciled = await cloud.reconcile(local: engine.state, remote: remote)
        if reconciled.lifetimeStardust > engine.state.lifetimeStardust {
            engine.state = reconciled
        }
    }
}
