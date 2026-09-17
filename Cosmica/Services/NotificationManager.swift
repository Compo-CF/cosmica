import Foundation
import Observation
import UIKit
import UserNotifications

/// v3.0 Phase 5 — local notifications (no APNs, no server). Two types ship in
/// 3.0:
///
///   1. "Reactor ready" — scheduled when the app goes to background. Fires
///      when the player would first be able to Big Bang (or at +1h if they
///      already can), capped at 24h out.
///   2. "Daily reward available" — scheduled 24h + 30-min-buffer after each
///      daily-reward claim.
///
/// Deliberately NOT included this release: "cosmic event active" notifications.
/// Cosmica's events spawn on the in-app tick loop, which suspends in background —
/// there's no reliable way to fire "event just started" from a scheduled trigger
/// without lying to users about when a real event will be waiting for them.
///
/// Permission is requested lazily from a Settings toggle, NOT from onboarding
/// (which is already carrying the ATT prompt). All scheduling is a no-op if
/// authorization != .authorized OR the per-type toggle is off — this keeps the
/// engine's scene-phase hook cheap and free-of-branching.
@MainActor
@Observable
final class NotificationManager: NSObject {
    // MARK: - UserDefaults keys

    private let masterKey  = "cosmica.notifications.master"
    private let reactorKey = "cosmica.notifications.reactor"
    private let dailyKey   = "cosmica.notifications.daily"

    // MARK: - Notification IDs (used for cancel / replace)

    private static let readyId = "cosmica.notif.reactor_ready"
    private static let dailyId = "cosmica.notif.daily_reward"

    // MARK: - Observable state

    /// Current system-level authorization status. Refreshed by
    /// `refreshAuthorizationStatus()` on app-boot and after each request.
    var authorizationStatus: UNAuthorizationStatus = .notDetermined

    /// Set by `userNotificationCenter(_:didReceive:)` when the user taps a
    /// notification. RootView observes and pushes the tab.
    var pendingTab: PendingTab? = nil

    enum PendingTab: String { case bigBang, observatory }

    // MARK: - Preferences (backed by UserDefaults)

    var masterEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: masterKey) }
        set { UserDefaults.standard.set(newValue, forKey: masterKey) }
    }

    var reactorEnabled: Bool {
        get { UserDefaults.standard.object(forKey: reactorKey) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: reactorKey) }
    }

    var dailyEnabled: Bool {
        get { UserDefaults.standard.object(forKey: dailyKey) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: dailyKey) }
    }

    // MARK: - Lifecycle

    func start() {
        UNUserNotificationCenter.current().delegate = self
        Task { await refreshAuthorizationStatus() }
    }

    func refreshAuthorizationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        authorizationStatus = settings.authorizationStatus
    }

    /// Master toggle handler. If we've never asked, request. If already denied,
    /// the caller should surface the "open iOS Settings" link separately.
    /// Returns true if permission is now granted.
    @discardableResult
    func requestPermission() async -> Bool {
        let center = UNUserNotificationCenter.current()
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
            await refreshAuthorizationStatus()
            if granted {
                masterEnabled = true
                return true
            } else {
                masterEnabled = false
                return false
            }
        } catch {
            masterEnabled = false
            return false
        }
    }

    // MARK: - Schedule / cancel

    /// Called from `CosmicaApp` when scenePhase → .background. Schedules any
    /// enabled notification types. No-op when the master toggle is off or the
    /// OS hasn't granted us permission.
    func scheduleAll(engine: GameEngine) {
        guard masterEnabled, authorizationStatus == .authorized else { return }
        cancelAll()
        if reactorEnabled { scheduleReactorReady(engine: engine) }
        if dailyEnabled   { scheduleDailyReward(engine: engine) }
    }

    /// Called from `CosmicaApp` when scenePhase → .active. Removes anything
    /// pending so we don't wake the player back up after they've opened the app.
    func cancelAll() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [Self.readyId, Self.dailyId]
        )
    }

    // MARK: - Individual schedulers

    private func scheduleReactorReady(engine: GameEngine) {
        let state = engine.state
        let interval: TimeInterval

        if engine.canPrestige {
            // Already prestigable — nudge in 1 hour if they haven't come back.
            interval = 3600
        } else if state.stardustPerSecond > 0, state.lifetimeStardust < PrestigeCalculator.threshold {
            let remaining = PrestigeCalculator.threshold - state.lifetimeStardust
            let etaSec = remaining / state.stardustPerSecond
            // Cap at 24h — anything longer is noise and battery.
            interval = min(max(60, etaSec), 24 * 3600)
        } else {
            // Player has no rate (unlikely mid-play) or already past threshold with
            // no shards — no honest ETA. Skip.
            return
        }

        let content = UNMutableNotificationContent()
        content.title = "Cosmica"
        content.body = engine.canPrestige
            ? "Your reactor is ready. Come collect your Cosmic Shards. ◈"
            : "Your reactor is warming up. It'll be ready to Big Bang."
        content.sound = .default
        content.userInfo = ["tab": PendingTab.bigBang.rawValue]

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        let request = UNNotificationRequest(
            identifier: Self.readyId,
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(request)
    }

    private func scheduleDailyReward(engine: GameEngine) {
        // If the reward is already available, don't schedule — they'd get pinged
        // 24h into the future for something already waiting for them.
        guard !engine.dailyRewardAvailable, let last = engine.state.lastDailyClaim else { return }
        // 24h + 30 min buffer so we don't fire before Cosmica's own gate clears.
        let interval = last.addingTimeInterval(24 * 3600 + 30 * 60).timeIntervalSinceNow
        guard interval > 60 else { return }  // don't schedule sub-minute

        let content = UNMutableNotificationContent()
        content.title = "Cosmica"
        content.body = "Your daily reward is ready to claim."
        content.sound = .default
        content.userInfo = ["tab": PendingTab.observatory.rawValue]

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        let request = UNNotificationRequest(
            identifier: Self.dailyId,
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Open iOS Settings deep-link

    /// Only useful when authorizationStatus == .denied — the app-store-blessed
    /// way to guide users back to the toggle.
    func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension NotificationManager: UNUserNotificationCenterDelegate {
    /// Show alerts even when the app is foreground (rare in practice — we cancel
    /// on foreground — but a race between fire+foreground can happen).
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    /// Tap handler — set pendingTab so RootView.onChange can switch tabs.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        let raw = userInfo["tab"] as? String
        Task { @MainActor in
            if let raw, let tab = PendingTab(rawValue: raw) {
                self.pendingTab = tab
            }
            completionHandler()
        }
    }
}
