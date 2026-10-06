import SwiftUI

/// v3.0.5 — shown once when an Automation trial runs out (rules in
/// `TrialEndOffer`). Leads with the Everything Bundle, which is what almost
/// every automation buyer picks; Automation Core sits underneath for players
/// who already own Remove Ads or only want automation.
///
/// Only products the App Store actually loaded get a button. RootView won't
/// present this at all unless the lead product is available, so there's never
/// a price on screen that can't be bought.
struct TrialEndOfferSheet: View {
    @Environment(IAPManager.self) private var iap
    @Environment(AutomationManager.self) private var automation
    @Environment(AdManager.self) private var ads
    @Environment(HapticsManager.self) private var haptics
    @Environment(ReviewPrompter.self) private var reviewPrompter
    let onDismiss: () -> Void

    @State private var errorText: String?

    /// Players who already own Remove Ads get Automation Core as the lead, since
    /// the bundle would charge them for ad removal twice.
    private var leadIsBundle: Bool { !iap.removeAdsOwned }

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "gearshape.2.fill")
                .font(.system(size: 54))
                .foregroundStyle(LinearGradient(colors: [.orange, .yellow], startPoint: .topLeading, endPoint: .bottomTrailing))
                .padding(.top, 24)

            Text("Your automation stopped")
                .font(.title2.bold())
                .foregroundStyle(.white)

            Text("The free trial is over, so auto-buy and auto Big Bang are paused. Keep them running for good:")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            VStack(spacing: 10) {
                if leadIsBundle, let price = iap.displayPrice(for: IAPManager.everythingBundleProductId) {
                    offerButton(title: "Everything Bundle · \(price)",
                                subtitle: "Automation + no ads, forever. Best value.",
                                productId: IAPManager.everythingBundleProductId,
                                prominent: true)
                }
                if let price = iap.displayPrice(for: IAPManager.automationCoreProductId) {
                    offerButton(title: leadIsBundle ? "Automation only · \(price)" : "Automation Core · \(price)",
                                subtitle: leadIsBundle ? nil : "Auto-buy and auto Big Bang, forever.",
                                productId: IAPManager.automationCoreProductId,
                                prominent: !leadIsBundle)
                }
            }
            .padding(.horizontal)

            if let errorText {
                Text(errorText)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            Spacer(minLength: 0)

            if ads.rewardedReady {
                Button("Watch an ad for 4 more hours", action: watchAd)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.orange)
            }
            Button("Not now", action: onDismiss)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.bottom, 20)
        }
        .frame(maxWidth: .infinity)
        .background(Color.black.ignoresSafeArea())
        .disabled(iap.purchaseInFlight)
    }

    @ViewBuilder
    private func offerButton(title: String, subtitle: String?, productId: String, prominent: Bool) -> some View {
        Button {
            Task { await buy(productId) }
        } label: {
            VStack(spacing: 2) {
                Text(title).font(.headline)
                if let subtitle {
                    Text(subtitle).font(.caption).opacity(0.8)
                }
            }
            .frame(maxWidth: .infinity, minHeight: subtitle == nil ? 44 : 56)
            .foregroundStyle(prominent ? .black : .white)
            .background(
                prominent
                    ? AnyShapeStyle(LinearGradient(colors: [.orange, .yellow], startPoint: .leading, endPoint: .trailing))
                    : AnyShapeStyle(Color.white.opacity(0.12)),
                in: RoundedRectangle(cornerRadius: 12)
            )
        }
    }

    @MainActor
    private func buy(_ productId: String) async {
        errorText = nil
        if await iap.purchase(productId) {
            haptics.purchase()
            onDismiss()
            // Same happy-moment review ask as the Shop, after the sheet is gone.
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                reviewPrompter.maybePrompt(reason: "purchase_\(productId)")
            }
        } else if let msg = iap.lastError, !msg.isEmpty {
            // User cancels leave lastError empty, and stay quiet.
            errorText = msg
            iap.lastError = nil
        }
    }

    private func watchAd() {
        guard let root = UIApplication.shared.topMostViewController() else { return }
        ads.showRewarded(from: root, onReward: {
            automation.grantTrial(hours: 4)
            haptics.upgrade()
            onDismiss()
        })
    }
}
