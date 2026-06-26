import SwiftUI

/// First-launch tutorial. Four paged cards explaining the core loop.
/// Dismisses to `hasSeenOnboarding = true` so it never reappears.
struct OnboardingView: View {
    @Environment(\.dismiss) var dismiss
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding: Bool = false
    @State private var page: Int = 0

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            symbol: "sparkles",
            color: Color(red: 0.62, green: 0.33, blue: 0.89),
            title: "Welcome to Cosmica",
            body: "You're an astronomer charting the universe. Tap the cosmic orb to earn Stardust ✦ — your fundamental currency."
        ),
        OnboardingPage(
            symbol: "scope",
            color: Color(red: 0.30, green: 0.70, blue: 0.95),
            title: "Build Your Observatory",
            body: "Spend Stardust on telescopes, probes, and megastructures. Each one earns Stardust automatically — even when the app is closed."
        ),
        OnboardingPage(
            symbol: "burst.fill",
            color: Color(red: 0.95, green: 0.55, blue: 0.30),
            title: "Big Bang to Ascend",
            body: "When you reach 1T lifetime Stardust, you can trigger the Big Bang — reset your generators in exchange for Cosmic Shards ◈, each granting permanent +2% earnings forever."
        ),
        OnboardingPage(
            symbol: "cart.fill",
            color: Color(red: 0.40, green: 0.85, blue: 0.50),
            title: "Boost Your Discovery",
            body: "The Shop offers temporary 2× boosts and offline catch-ups — earned by watching short ads or purchased directly. Have fun, observer."
        ),
    ]

    var body: some View {
        ZStack {
            background
            VStack(spacing: 0) {
                TabView(selection: $page) {
                    ForEach(pages.indices, id: \.self) { i in
                        pageCard(pages[i]).tag(i)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .indexViewStyle(.page(backgroundDisplayMode: .always))

                Button(action: advance) {
                    Text(page == pages.count - 1 ? "Start Playing" : "Next")
                        .font(.headline)
                        .frame(maxWidth: .infinity, minHeight: 54)
                        .background(
                            LinearGradient(
                                colors: [pages[page].color, pages[page].color.opacity(0.7)],
                                startPoint: .leading, endPoint: .trailing
                            ),
                            in: RoundedRectangle(cornerRadius: 14)
                        )
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
        }
        .overlay(alignment: .topTrailing) {
            if page < pages.count - 1 {
                Button("Skip") { finish() }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding()
            }
        }
        .interactiveDismissDisabled(true)
    }

    private var background: some View {
        LinearGradient(
            colors: [.black, Color(red: 0.04, green: 0.0, blue: 0.16), .black],
            startPoint: .top, endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    @ViewBuilder
    private func pageCard(_ page: OnboardingPage) -> some View {
        VStack(spacing: 24) {
            Spacer()
            ZStack {
                Circle()
                    .fill(RadialGradient(
                        colors: [page.color.opacity(0.8), page.color.opacity(0.0)],
                        center: .center, startRadius: 5, endRadius: 140))
                    .frame(width: 240, height: 240)
                Image(systemName: page.symbol)
                    .font(.system(size: 80))
                    .foregroundStyle(.white)
                    .shadow(color: page.color, radius: 20)
            }
            Text(page.title)
                .font(.largeTitle.bold())
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
            Text(page.body)
                .font(.body)
                .foregroundStyle(.white.opacity(0.85))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
            Spacer()
        }
    }

    private func advance() {
        if page < pages.count - 1 {
            withAnimation { page += 1 }
        } else {
            finish()
        }
    }

    private func finish() {
        hasSeenOnboarding = true
        dismiss()
    }
}

private struct OnboardingPage {
    let symbol: String
    let color: Color
    let title: String
    let body: String
}
