import SwiftUI

/// v3.0 — one-shot "here's what's new" sheet shown to every existing player on
/// their first launch of Cosmica 3.0. Gated in `RootView` by
/// `@AppStorage("hasSeenWhatsNew_3_0")` so it never re-appears.
///
/// Content deliberately mirrors what actually ships in v3.0 (Phases 1-6 folded
/// into the final App Store build). Update the copy AND rename the AppStorage
/// key each major-version release so a new "what's new" fires exactly once
/// after that version installs.
struct WhatsNewSheet: View {
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 22) {
                    header
                    features
                    fine
                }
                .padding(.horizontal, 24)
                .padding(.top, 32)
                .padding(.bottom, 24)
            }
            dismissButton
        }
        .background(background)
        .interactiveDismissDisabled(false)
    }

    private var header: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        colors: [Color.purple, Color.indigo],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ))
                    .frame(width: 88, height: 88)
                    .shadow(color: .purple.opacity(0.6), radius: 18)
                Image(systemName: "gearshape.2.fill")
                    .font(.system(size: 40, weight: .bold))
                    .foregroundStyle(.white)
            }
            Text("Cosmica 3.0")
                .font(.largeTitle.bold())
                .foregroundStyle(.white)
            Text("The Automation Update")
                .font(.title3)
                .foregroundStyle(.secondary)
        }
    }

    private var features: some View {
        VStack(alignment: .leading, spacing: 18) {
            featureRow(
                icon: "gearshape.2.fill",
                tint: .orange,
                title: "Auto-buy generators",
                detail: "Unlock the new Autonomy branch on the Cosmic Tree, then toggle the gear on any generator to buy it for you."
            )
            featureRow(
                icon: "burst.fill",
                tint: .purple,
                title: "Auto-Big-Bang",
                detail: "Set a shard threshold in the Big Bang tab. Prestige runs on autopilot when the number is right."
            )
            featureRow(
                icon: "circle.hexagongrid.fill",
                tint: .cyan,
                title: "Auto-spend the Cosmic Tree",
                detail: "After each Big Bang, banked Cosmic Shards buy the cheapest available tree node — leaving you 100 in reserve for anything you're saving for."
            )
            featureRow(
                icon: "bell.badge.fill",
                tint: .cyan,
                title: "Notifications & home widget",
                detail: "Optional push when your reactor is ready. A widget on your home screen keeps the numbers close."
            )
            featureRow(
                icon: "sparkles.rectangle.stack.fill",
                tint: .yellow,
                title: "Unlock in the Shop",
                detail: "Try Automation free for 4 hours with a rewarded ad, or unlock it forever with Automation Core."
            )
        }
    }

    private var fine: some View {
        VStack(spacing: 8) {
            Text("Your progress, purchases, and Game Center scores all carry forward. Nothing was reset.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 4)
    }

    private var dismissButton: some View {
        Button {
            onDismiss()
        } label: {
            Text("Get Started")
                .font(.headline)
                .frame(maxWidth: .infinity, minHeight: 54)
                .background(
                    LinearGradient(colors: [.purple, .indigo],
                                   startPoint: .leading, endPoint: .trailing),
                    in: RoundedRectangle(cornerRadius: 14)
                )
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 24)
    }

    private var background: some View {
        ZStack {
            Color.black
            RadialGradient(
                colors: [Color.purple.opacity(0.35), .clear],
                center: .top, startRadius: 20, endRadius: 400
            )
        }
        .ignoresSafeArea()
    }

    private func featureRow(icon: String, tint: Color, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(tint)
                .frame(width: 30, height: 30)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.white)
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
    }
}
