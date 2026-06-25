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
struct BannerAdSlot: View {
    @Environment(AdManager.self) var ads

    var body: some View {
        if ads.removeAdsOwned {
            EmptyView()
        } else {
            BannerAdView(unitId: ads.bannerUnitId)
                .frame(height: 50)
        }
    }
}
