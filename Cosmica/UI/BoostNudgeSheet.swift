import SwiftUI

/// Post-Big-Bang IAP nudge (v2.1). Presented from `BigBangView` after the 3rd,
/// 7th, or 15th prestige for players who:
///   - don't already own Remove Ads (already-engaged users are left alone)
///   - don't currently have an active 2× boost
///   - haven't been shown this sheet in the last 7 days (see IAPManager.boostNudgeEligible)
///
/// The player has three exits: buy the boost pack, watch a rewarded ad for a
/// smaller free version, or dismiss. Any of the three ends the modal cleanly.
struct BoostNudgeSheet: View {
    @Environment(GameEngine.self) private var engine
    @Environment(IAPManager.self) private var iap
    @Environment(AdManager.self) private var ads
    @Environment(HapticsManager.self) private var haptics
    @Environment(\.dismiss) private var dismiss

    @State private var busy = false

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "bolt.circle.fill")
                .font(.system(size: 72))
                .foregroundStyle(
                    LinearGradient(colors: [.yellow, .orange], startPoint: .top, endPoint: .bottom)
                )
                .shadow(color: Color.orange.opacity(0.6), radius: 20)
                .padding(.top, 28)

            Text("Your fresh universe is ready to grow.")
                .font(.title3.bold())
                .multilineTextAlignment(.center)
                .padding(.horizontal, 28)

            Text("Supercharge it 2× for 24 hours.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            VStack(spacing: 10) {
                if let product = iap.product(for: IAPManager.boost2x24hrProductId) {
                    Button {
                        Task {
                            busy = true
                            let ok = await iap.purchase(product.id)
                            busy = false
                            if ok {
                                engine.grantBoost(duration: 24 * 3600)
                                haptics.upgrade()
                                dismiss()
                            }
                        }
                    } label: {
                        VStack(spacing: 3) {
                            Text("Buy — 2× for 24 hours")
                                .font(.headline)
                            Text(product.displayPrice)
                                .font(.subheadline)
                                .opacity(0.9)
                        }
                        .frame(maxWidth: .infinity, minHeight: 58)
                        .background(
                            LinearGradient(colors: [.orange, .yellow], startPoint: .leading, endPoint: .trailing),
                            in: RoundedRectangle(cornerRadius: 14)
                        )
                        .foregroundStyle(.black)
                    }
                    .disabled(busy)
                }

                Button {
                    guard let root = Self.topViewController() else { dismiss(); return }
                    busy = true
                    ads.showRewarded(from: root, onReward: {
                        engine.grantBoost(duration: 3600) // free 1-hour version
                        haptics.upgrade()
                    }, onDismiss: {
                        busy = false
                        dismiss()
                    })
                } label: {
                    HStack {
                        Image(systemName: "play.rectangle.fill")
                        Text(ads.rewardedReady ? "Watch Ad — 1 hour free" : "Ad loading…")
                    }
                    .font(.subheadline.bold())
                    .frame(maxWidth: .infinity, minHeight: 46)
                    .background(Color.gray.opacity(0.18), in: RoundedRectangle(cornerRadius: 12))
                    .foregroundStyle(.primary)
                }
                .disabled(busy || !ads.rewardedReady)

                Button("Not now") {
                    dismiss()
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.top, 2)
            }
            .padding(.horizontal, 20)

            Spacer(minLength: 0)
        }
        .padding(.bottom, 20)
        .presentationDetents([.medium])
    }

    /// Best-effort resolution of the current top-of-stack UIViewController for
    /// presenting the rewarded ad from. GoogleMobileAds needs a real UIVC —
    /// SwiftUI doesn't hand you one directly.
    private static func topViewController() -> UIViewController? {
        guard let scene = UIApplication.shared.connectedScenes
            .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
              let window = scene.windows.first(where: \.isKeyWindow) ?? scene.windows.first,
              var top = window.rootViewController
        else { return nil }
        while let presented = top.presentedViewController { top = presented }
        return top
    }
}
