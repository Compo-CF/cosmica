import SwiftUI
import GoogleMobileAds

/// SwiftUI bridge for AdMob's adaptive banner.
struct BannerAdView: UIViewRepresentable {
    let unitId: String

    func makeUIView(context: Context) -> BannerView {
        let view = BannerView(adSize: AdSizeBanner)
        view.adUnitID = unitId
        view.rootViewController = topViewController()
        view.load(Request())
        return view
    }

    func updateUIView(_ uiView: BannerView, context: Context) {
        if uiView.rootViewController == nil {
            uiView.rootViewController = topViewController()
        }
    }

    private func topViewController() -> UIViewController? {
        guard let scene = UIApplication.shared.connectedScenes
            .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
              let window = scene.windows.first(where: { $0.isKeyWindow }),
              var top = window.rootViewController
        else { return nil }
        while let presented = top.presentedViewController { top = presented }
        return top
    }
}

/// Convenience modifier so views can drop in `BannerAdSlot()` without import noise.
///
/// v3.0.1 — self-cycling visibility. The banner is visible for `visibleWindow`
/// seconds, then hides for `hiddenWindow` seconds, on repeat. Height collapses
/// to 0 while hidden so the surrounding layout (e.g. Observatory's generator
/// list) reclaims that ~50pt for however long the banner is off-screen.
///
/// Trade-off: ~57% of the previous impression rate for materially less visible
/// clutter on the primary tab where players spend most of their session.
/// Effective eCPM often stays even or improves because each returning
/// impression is fresher and more attended-to.
struct BannerAdSlot: View {
    @Environment(AdManager.self) var ads
    @State private var visible: Bool = true

    /// Seconds the banner is on-screen per cycle.
    private let visibleWindow: TimeInterval = 60
    /// Seconds the banner is fully hidden per cycle (layout reclaims the space).
    private let hiddenWindow: TimeInterval = 45

    var body: some View {
        if ads.removeAdsOwned {
            EmptyView()
        } else {
            BannerAdView(unitId: ads.bannerUnitId)
                .frame(height: visible ? 50 : 0)
                .opacity(visible ? 1 : 0)
                .clipped()
                .animation(.easeInOut(duration: 0.45), value: visible)
                .task {
                    // Endless visibility cycle; ends when the view goes away.
                    while !Task.isCancelled {
                        try? await Task.sleep(nanoseconds: UInt64(visibleWindow * 1_000_000_000))
                        if Task.isCancelled { break }
                        visible = false
                        try? await Task.sleep(nanoseconds: UInt64(hiddenWindow * 1_000_000_000))
                        if Task.isCancelled { break }
                        visible = true
                    }
                }
        }
    }
}
