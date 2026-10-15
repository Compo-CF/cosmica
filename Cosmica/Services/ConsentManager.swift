import AppTrackingTransparency
import Foundation
import Observation
import UIKit
// The SPM product is "GoogleUserMessagingPlatform", but the module inside it is "UserMessagingPlatform".
import UserMessagingPlatform

/// v3.1.2 — Google UMP consent (EEA, UK, Switzerland and other regulated regions), then Apple's
/// tracking prompt. Ported from Alchemica.
///
/// Order matters (Google's guidance): consent form first, ATT second, and the Mobile Ads SDK
/// only starts once `canRequestAds` is true. Outside regulated regions UMP shows nothing and
/// `canRequestAds` becomes true right away. The form itself is the GDPR message published in
/// AdMob > Privacy & messaging.
@MainActor
@Observable
final class ConsentManager {
    private(set) var canRequestAds = ConsentInformation.shared.canRequestAds
    /// True where regulations require a way to change consent later ("Privacy choices" in Settings).
    private(set) var privacyOptionsRequired = false
    private var gathering = false

    /// Refresh consent status and show the consent form if this player needs it.
    func gather() async {
        guard !gathering else { return }
        gathering = true
        defer { gathering = false }
        do {
            try await ConsentInformation.shared.requestConsentInfoUpdate(with: RequestParameters())
            if let root = Self.topViewController() {
                try await ConsentForm.loadAndPresentIfRequired(from: root)
            }
        } catch {
            // Network or configuration problems: fall back to whatever consent we already have.
            print("[Consent] \(error.localizedDescription)")
        }
        refresh()
    }

    /// Re-open the consent form from Settings.
    func presentPrivacyOptions() async {
        guard let root = Self.topViewController() else { return }
        do {
            try await ConsentForm.presentPrivacyOptionsForm(from: root)
        } catch {
            print("[Consent] privacy options: \(error.localizedDescription)")
        }
        refresh()
    }

    /// Apple's tracking prompt, asked once, after consent.
    func requestTrackingIfNeeded() async {
        guard ATTrackingManager.trackingAuthorizationStatus == .notDetermined else { return }
        try? await Task.sleep(nanoseconds: 500_000_000)   // let any dismissed sheet finish animating
        _ = await ATTrackingManager.requestTrackingAuthorization()
    }

    private func refresh() {
        canRequestAds = ConsentInformation.shared.canRequestAds
        privacyOptionsRequired = ConsentInformation.shared.privacyOptionsRequirementStatus == .required
    }

    private static func topViewController() -> UIViewController? {
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
        var top = scene?.windows.first { $0.isKeyWindow }?.rootViewController
        while let presented = top?.presentedViewController {
            top = presented
        }
        return top
    }
}
