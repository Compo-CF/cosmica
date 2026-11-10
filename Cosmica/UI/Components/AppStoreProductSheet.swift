import SwiftUI
import StoreKit

/// v3.5 — Presents the Apple App Store product page for a given numeric App Store
/// identifier, inline in Cosmica (no app-switch). Used by the "More from After
/// Hours Dev Studio" shelf so a tap feels native and the user stays in Cosmica.
///
/// Wrap in a `.sheet`:
///
///     .sheet(item: $selectedGame) { game in
///         AppStoreProductSheet(appStoreID: game.appStoreID)
///             .ignoresSafeArea()
///     }
struct AppStoreProductSheet: UIViewControllerRepresentable {
    let appStoreID: String

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIViewController(context: Context) -> SKStoreProductViewController {
        let vc = SKStoreProductViewController()
        vc.delegate = context.coordinator
        let params: [String: Any] = [
            SKStoreProductParameterITunesItemIdentifier: appStoreID
        ]
        // Loading is async; the shell shows a spinner until the product arrives.
        vc.loadProduct(withParameters: params) { _, _ in }
        return vc
    }

    func updateUIViewController(_ uiViewController: SKStoreProductViewController, context: Context) {}

    final class Coordinator: NSObject, SKStoreProductViewControllerDelegate {
        func productViewControllerDidFinish(_ viewController: SKStoreProductViewController) {
            viewController.dismiss(animated: true)
        }
    }
}
