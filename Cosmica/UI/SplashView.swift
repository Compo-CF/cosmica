import SwiftUI

/// Cold-launch splash. Rendered as an overlay on top of `RootView` by `CosmicaApp`
/// for ~1.5 s at start; fades out on its own. Shows the shipping version + build
/// number pulled from the app bundle so QA / TestFlight testers can always name
/// the exact build without digging in Settings.
struct SplashView: View {
    @State private var appear = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            RadialGradient(
                colors: [Color.purple.opacity(0.45), .clear],
                center: .center, startRadius: 5, endRadius: 420
            )
            .ignoresSafeArea()

            VStack(spacing: 20) {
                Image(systemName: "sparkles")
                    .font(.system(size: 90, weight: .thin))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                Color(red: 0.70, green: 0.35, blue: 0.98),
                                Color(red: 0.30, green: 0.90, blue: 1.00),
                                Color(red: 1.00, green: 0.55, blue: 0.90),
                            ],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: Color.purple.opacity(0.7), radius: 34)
                    .scaleEffect(appear ? 1 : 0.75)
                    .opacity(appear ? 1 : 0)

                Text("Cosmica")
                    .font(.system(size: 46, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .opacity(appear ? 1 : 0)

                Text(Self.versionLine)
                    .font(.system(size: 14, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.55))
                    .opacity(appear ? 1 : 0)
            }
            .animation(.easeOut(duration: 0.75), value: appear)
        }
        .onAppear { appear = true }
    }

    /// `v2.0.0 (14)` — CFBundleShortVersionString + CFBundleVersion from the running build.
    /// Static so a fresh SplashView on every launch doesn't re-read Info.plist.
    static let versionLine: String = {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "v\(short) (\(build))"
    }()
}
