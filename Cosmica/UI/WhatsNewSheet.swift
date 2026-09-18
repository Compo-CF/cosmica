import SwiftUI

/// v3.0 — paginated "here's what's new" walkthrough. Four cards covering the
/// major features returning players should re-notice: the new Automation Core
/// (Phase 1-5 of the release), plus three long-standing systems that endgame
/// players sometimes miss — Generator Specialization, Cosmic Tree, Cosmic
/// Wonders.
///
/// Shown once per install per major version, gated in `RootView` by
/// `@AppStorage("hasSeenWhatsNew_3_0")`. Update the copy AND rename the
/// AppStorage key each major-version release so a new "what's new" fires
/// exactly once after that version installs.
struct WhatsNewSheet: View {
    let onDismiss: () -> Void

    @State private var pageIndex: Int = 0

    /// Cards in order. Automation first (the thing they'll open the app to
    /// explore), then three system reminders that compound with automation.
    private let cards: [Card] = [
        Card(
            eyebrow: "New in 3.0",
            title: "Automation",
            subtitle: "Your universe now runs on its own.",
            icon: "gearshape.2.fill",
            tintGradient: [.orange, .yellow],
            bullets: [
                Bullet(icon: "circle.grid.3x3.fill", text: "Auto-buy generators — unlock the Autonomy branch on the Cosmic Tree, then toggle the gear on any generator."),
                Bullet(icon: "burst.fill",           text: "Auto-Big-Bang — pick a shard threshold in the Big Bang tab, and prestige runs itself."),
                Bullet(icon: "circle.hexagongrid.fill", text: "Auto-spend Cosmic Shards — banked shards flow into your cheapest tree node after every Big Bang."),
                Bullet(icon: "bell.badge.fill",      text: "Optional local notifications when your reactor is ready.")
            ],
            footnote: "Try 4 hours free by watching an ad in the Shop, or unlock Automation Core forever."
        ),
        Card(
            eyebrow: "Long-press to commit",
            title: "Generator Specialization",
            subtitle: "Each generator can lock in one permanent buff.",
            icon: "flame.circle.fill",
            tintGradient: [.pink, .purple],
            bullets: [
                Bullet(icon: "hand.tap.fill",        text: "Tap the info icon on any owned generator to open its detail sheet."),
                Bullet(icon: "arrow.triangle.branch", text: "Pick a specialization — the choice is permanent for this Big Bang cycle."),
                Bullet(icon: "arrow.clockwise",       text: "Specializations reset at every Big Bang, so experiment freely.")
            ],
            footnote: "Specialization unlocks after you've bought a handful of that generator."
        ),
        Card(
            eyebrow: "◈ Cosmic Shards → permanent upgrades",
            title: "The Cosmic Tree",
            subtitle: "Every Big Bang leaves you with Cosmic Shards. Spend them here.",
            icon: "circle.hexagongrid.fill",
            tintGradient: [.cyan, .blue],
            bullets: [
                Bullet(icon: "sparkles",              text: "Levels persist across every Big Bang — permanent power."),
                Bullet(icon: "scope",                 text: "Cluster nodes buff whole tiers of generators at once."),
                Bullet(icon: "gearshape.2.fill",      text: "The new Autonomy branch unlocks auto-buy per generator cluster.")
            ],
            footnote: "Unspent Cosmic Shards ALSO grant +2% earnings each — a real invest-or-hoard choice."
        ),
        Card(
            eyebrow: "5 permanent unlocks",
            title: "Cosmic Wonders",
            subtitle: "Wonders survive Big Bang AND True Cosmos.",
            icon: "building.columns.fill",
            tintGradient: [.yellow, .orange],
            bullets: [
                Bullet(icon: "clock.fill",            text: "Chronosphere — +12h offline earning cap"),
                Bullet(icon: "sparkles",              text: "Nexus Lattice — ×3 stardust during Cosmic Events"),
                Bullet(icon: "burst.fill",            text: "Voidkeeper — +50% Big Bang shard yield"),
                Bullet(icon: "hand.tap.fill",         text: "Multiverse Engine — ×2 manual tap value"),
                Bullet(icon: "infinity.circle.fill",  text: "Absolute Aperture — +25% Reality Fragments per True Cosmos")
            ],
            footnote: "The Wonders tab appears once you've completed at least one True Cosmos."
        )
    ]

    var body: some View {
        VStack(spacing: 0) {
            topBar
            TabView(selection: $pageIndex) {
                ForEach(cards.indices, id: \.self) { i in
                    card(cards[i])
                        .tag(i)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))
            bottomButton
        }
        .background(background)
    }

    private var topBar: some View {
        HStack {
            Text("Cosmica 3.0")
                .font(.headline)
                .foregroundStyle(.white)
            Spacer()
            Button("Skip") {
                onDismiss()
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
    }

    private func card(_ c: Card) -> some View {
        ScrollView {
            VStack(spacing: 20) {
                heroIcon(icon: c.icon, gradient: c.tintGradient)
                    .padding(.top, 12)
                VStack(spacing: 8) {
                    Text(c.eyebrow.uppercased())
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                        .tracking(1.2)
                    Text(c.title)
                        .font(.largeTitle.bold())
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                    Text(c.subtitle)
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(c.bullets.indices, id: \.self) { i in
                        bulletRow(c.bullets[i], tint: c.tintGradient.first ?? .white)
                    }
                }
                .padding(.horizontal, 4)
                if !c.footnote.isEmpty {
                    Text(c.footnote)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.top, 4)
                }
                Spacer(minLength: 30)  // room above the page indicator
            }
            .padding(.horizontal, 24)
            .padding(.top, 12)
        }
    }

    private func heroIcon(icon: String, gradient: [Color]) -> some View {
        ZStack {
            Circle()
                .fill(LinearGradient(colors: gradient,
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 96, height: 96)
                .shadow(color: (gradient.first ?? .white).opacity(0.55), radius: 22)
            Image(systemName: icon)
                .font(.system(size: 44, weight: .bold))
                .foregroundStyle(.white)
        }
    }

    private func bulletRow(_ b: Bullet, tint: Color) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: b.icon)
                .font(.subheadline)
                .foregroundStyle(tint)
                .frame(width: 24, alignment: .center)
                .padding(.top, 3)
            Text(b.text)
                .font(.subheadline)
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }

    private var bottomButton: some View {
        Button {
            if pageIndex < cards.count - 1 {
                withAnimation(.easeInOut(duration: 0.25)) {
                    pageIndex += 1
                }
            } else {
                onDismiss()
            }
        } label: {
            HStack {
                Text(pageIndex < cards.count - 1 ? "Next" : "Get Started")
                    .font(.headline)
                if pageIndex < cards.count - 1 {
                    Image(systemName: "chevron.right")
                        .font(.subheadline.bold())
                }
            }
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
        .padding(.top, 4)
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

    // MARK: - Data model

    private struct Card {
        let eyebrow: String
        let title: String
        let subtitle: String
        let icon: String
        let tintGradient: [Color]
        let bullets: [Bullet]
        let footnote: String
    }

    private struct Bullet {
        let icon: String
        let text: String
    }
}
