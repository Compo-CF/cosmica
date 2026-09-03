import SwiftUI

/// The end-of-the-ladder moment. Fires exactly once, the first time a player's lifetime
/// Stardust crosses `Tier.absolute.threshold` (1e36 ✦). Deliberately theatrical — this is
/// the biggest thing that will ever happen in Cosmica's progression, and the player just
/// spent hundreds of hours reaching it. Grants 500 bonus Cosmic Shards on entry (handled
/// engine-side) and unlocks the "Absolute Observer" title shown on the Tier card and in
/// Settings from then on.
struct AbsoluteAscensionView: View {
    @Environment(GameEngine.self) var engine
    @Environment(HapticsManager.self) var haptics
    @Environment(\.dismiss) var dismiss

    @State private var titleVisible = false
    @State private var bodyVisible = false
    @State private var rewardVisible = false
    @State private var buttonVisible = false

    var body: some View {
        ZStack {
            iridescentBackground
            starField
            VStack(spacing: 24) {
                Spacer()
                rotatingInfinity
                    .padding(.bottom, 8)

                Text("ABSOLUTE OBSERVER")
                    .font(.system(size: 34, weight: .heavy, design: .rounded))
                    .kerning(4)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.white, Color(red: 1.0, green: 0.8, blue: 0.95), Color(red: 0.85, green: 0.9, blue: 1.0)],
                            startPoint: .leading, endPoint: .trailing
                        )
                    )
                    .multilineTextAlignment(.center)
                    .opacity(titleVisible ? 1 : 0)
                    .scaleEffect(titleVisible ? 1 : 0.85)

                Text("You have witnessed the origin behind the origin.")
                    .font(.title3.weight(.medium))
                    .foregroundStyle(.white.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .opacity(bodyVisible ? 1 : 0)

                Text("Every star you named. Every wave of Stardust you gathered. All of it led here — to the observer looking back at everything.")
                    .font(.callout)
                    .foregroundStyle(.white.opacity(0.65))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .padding(.top, 4)
                    .opacity(bodyVisible ? 1 : 0)

                rewardCard
                    .opacity(rewardVisible ? 1 : 0)
                    .scaleEffect(rewardVisible ? 1 : 0.85)
                    .padding(.top, 8)

                Spacer()

                Button(action: acknowledge) {
                    Text("Continue Observing")
                        .font(.headline)
                        .frame(maxWidth: .infinity, minHeight: 54)
                        .background(
                            LinearGradient(
                                colors: [Color(red: 1.0, green: 0.55, blue: 0.90), Color(red: 0.55, green: 0.20, blue: 0.95)],
                                startPoint: .leading, endPoint: .trailing
                            ),
                            in: RoundedRectangle(cornerRadius: 14)
                        )
                        .foregroundStyle(.white)
                        .shadow(color: Color(red: 1.0, green: 0.55, blue: 0.90).opacity(0.6), radius: 20)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
                .opacity(buttonVisible ? 1 : 0)
            }
        }
        .interactiveDismissDisabled(true)
        .onAppear { runIntro() }
    }

    // MARK: - Sequenced reveal

    private func runIntro() {
        haptics.bigBang()
        withAnimation(.easeOut(duration: 0.9).delay(0.4)) { titleVisible = true }
        withAnimation(.easeOut(duration: 0.9).delay(1.6)) { bodyVisible = true }
        withAnimation(.spring(response: 0.6, dampingFraction: 0.55).delay(2.8)) { rewardVisible = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.8) { haptics.skillUnlock() }
        withAnimation(.easeOut(duration: 0.7).delay(4.0)) { buttonVisible = true }
    }

    private func acknowledge() {
        haptics.upgrade()
        engine.acknowledgeAscension()
        dismiss()
        // Happy-moment: they just crossed the biggest threshold in the game.
        // Delay so the dismiss animation finishes and the prompt lands in the
        // "wow that was cool" beat rather than on top of the cover transition.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            reviewPrompter.maybePrompt(reason: "absolute_ascension")
        }
    }

    // MARK: - Composition

    /// Slow-rotating conic gradient behind everything — the aesthetic anchor. Uses
    /// TimelineView so the rotation runs independently of engine state changes.
    private var iridescentBackground: some View {
        TimelineView(.animation) { ctx in
            let angle = Angle.degrees(ctx.date.timeIntervalSince1970.truncatingRemainder(dividingBy: 60) * 6)
            ZStack {
                Color.black
                AngularGradient(
                    gradient: Gradient(colors: [
                        Color(red: 1.0, green: 0.55, blue: 0.90),
                        Color(red: 0.55, green: 0.20, blue: 0.95),
                        Color(red: 0.30, green: 0.90, blue: 1.00),
                        Color(red: 1.0, green: 0.72, blue: 0.20),
                        Color(red: 1.0, green: 0.55, blue: 0.90),
                    ]),
                    center: .center,
                    angle: angle
                )
                .opacity(0.35)
                .blur(radius: 120)
            }
            .ignoresSafeArea()
        }
    }

    /// Deterministic starfield — same seed every render so the sky doesn't reshuffle.
    private var starField: some View {
        Canvas { ctx, size in
            var rng = SplitMix64(seed: 0xAB50_1017_1B5E_C0DE)
            for _ in 0..<180 {
                let x = CGFloat(rng.next01()) * size.width
                let y = CGFloat(rng.next01()) * size.height
                let r = CGFloat(0.5 + rng.next01() * 2.0)
                let opacity = 0.5 + rng.next01() * 0.5
                ctx.fill(Path(ellipseIn: CGRect(x: x, y: y, width: r, height: r)),
                         with: .color(Color.white.opacity(opacity)))
            }
        }
        .allowsHitTesting(false)
        .ignoresSafeArea()
    }

    /// The infinity symbol that rotates slowly and glows through the iridescent palette.
    private var rotatingInfinity: some View {
        TimelineView(.animation) { ctx in
            let angle = Angle.degrees(ctx.date.timeIntervalSince1970.truncatingRemainder(dividingBy: 30) * 12)
            ZStack {
                Circle()
                    .fill(RadialGradient(
                        colors: [Color(red: 1.0, green: 0.55, blue: 0.90).opacity(0.6), .clear],
                        center: .center, startRadius: 4, endRadius: 140
                    ))
                    .frame(width: 300, height: 300)
                    .blur(radius: 20)

                Image(systemName: "infinity.circle.fill")
                    .font(.system(size: 130, weight: .thin))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color(red: 1.0, green: 0.55, blue: 0.90), Color(red: 0.30, green: 0.90, blue: 1.00), Color(red: 1.0, green: 0.72, blue: 0.20)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
                    .rotationEffect(angle)
                    .shadow(color: Color(red: 0.55, green: 0.20, blue: 0.95).opacity(0.8), radius: 40)
            }
        }
    }

    private var rewardCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "diamond.fill")
                .font(.title)
                .foregroundStyle(.cyan)
            VStack(alignment: .leading, spacing: 2) {
                Text("+\(GameEngine.absoluteAscensionShardBonus) Cosmic Shards ◈")
                    .font(.title3.bold())
                    .foregroundStyle(.white)
                Text("A one-time recognition. Yours to keep.")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
            }
            Spacer()
        }
        .padding(16)
        .background(
            LinearGradient(colors: [Color.white.opacity(0.14), Color.white.opacity(0.06)], startPoint: .top, endPoint: .bottom),
            in: RoundedRectangle(cornerRadius: 14)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.25), lineWidth: 1)
        )
        .padding(.horizontal, 24)
    }
}

/// Tiny deterministic RNG. Same shape used for the Observatory starfield; kept private
/// here so this view has no import from elsewhere in the codebase.
private struct SplitMix64 {
    var state: UInt64
    init(seed: UInt64) { self.state = seed == 0 ? 1 : seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z &>> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z &>> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z &>> 31)
    }
    mutating func next01() -> Double {
        Double(next() % 10_000) / 10_000.0
    }
}
