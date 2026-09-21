import SwiftUI

/// Main game screen — tap zone + generator list.
struct ObservatoryView: View {
    @Environment(GameEngine.self) var engine
    @Environment(HapticsManager.self) var haptics
    /// v3.0.1: adaptive tap-zone sizing. `.compact` = shorter iPhones (Plus/Pro
    /// landscape, or very small portrait). We shrink further there so the
    /// generator list has room to breathe.
    @Environment(\.verticalSizeClass) private var vSizeClass
    @State private var floats: [Floater] = []

    struct Floater: Identifiable { let id = UUID(); let value: Double; let x: CGFloat }

    var body: some View {
        ZStack {
            background
            VStack(spacing: 0) {
                CurrencyBar()
                tierStrip
                if let event = engine.state.activeEvent {
                    eventBanner(event)
                }
                tapZone
                generatorList
                BannerAdSlot()
            }
        }
    }

    /// Live banner shown while a Cosmic Event is running. Updates its own remaining-time
    /// text every second via a Timer.publish so the countdown feels responsive.
    private func eventBanner(_ event: CosmicEvent) -> some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let secs = max(0, engine.state.activeEventExpiresAt?.timeIntervalSince(context.date) ?? 0)
            HStack(spacing: 10) {
                Image(systemName: event.symbol)
                    .foregroundStyle(.orange)
                VStack(alignment: .leading, spacing: 2) {
                    Text(event.name).font(.subheadline.bold()).foregroundStyle(.white)
                    Text(event.detail).font(.caption).foregroundStyle(.orange)
                }
                Spacer()
                Text(Formatter.duration(secs))
                    .font(.caption.bold())
                    .foregroundStyle(.orange)
                    .monospacedDigit()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                LinearGradient(colors: [.orange.opacity(0.28), .red.opacity(0.14)], startPoint: .leading, endPoint: .trailing),
                in: RoundedRectangle(cornerRadius: 10)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10).stroke(Color.orange.opacity(0.5), lineWidth: 1)
            )
        }
        .padding(.horizontal)
        .padding(.top, 2)
    }

    // MARK: - Components

    private var background: some View {
        LinearGradient(
            colors: [.black, Color(red: 0.05, green: 0.0, blue: 0.18), .black],
            startPoint: .top, endPoint: .bottom
        )
        .overlay {
            // Stars
            Canvas { ctx, size in
                let seed: UInt64 = 0xC051_CA00_C051_CA00
                var rng = SeededGenerator(seed: seed)
                for _ in 0..<120 {
                    let x = CGFloat(rng.next01()) * size.width
                    let y = CGFloat(rng.next01()) * size.height
                    let r = CGFloat(0.5 + rng.next01() * 1.6)
                    let opacity = 0.3 + rng.next01() * 0.7
                    ctx.fill(Path(ellipseIn: CGRect(x: x, y: y, width: r, height: r)),
                             with: .color(Color.white.opacity(opacity)))
                }
            }
            .allowsHitTesting(false)
        }
        .ignoresSafeArea()
    }

    private var tierStrip: some View {
        let tier = engine.state.currentTier
        return HStack {
            Image(systemName: tier.symbol).foregroundStyle(tier.color)
            Text(tier.title).font(.subheadline.weight(.semibold)).foregroundStyle(.white)
            Spacer()
            Text("×\(String(format: "%.2f", tier.multiplier))").font(.caption.bold()).foregroundStyle(tier.color)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    /// v3.0.1: adaptive tap-orb size. Shorter iPhones lose ~30pt in the orb
    /// and matching padding so the generator list gets 1-2 more visible rows.
    private var orbSize: CGFloat { vSizeClass == .compact ? 140 : 170 }
    private var orbSymbolSize: CGFloat { vSizeClass == .compact ? 40 : 48 }
    private var tapZoneVerticalPad: CGFloat { vSizeClass == .compact ? 8 : 12 }

    private var tapZone: some View {
        ZStack {
            Circle()
                .fill(RadialGradient(
                    colors: [engine.state.currentTier.color.opacity(0.9),
                             engine.state.currentTier.color.opacity(0.2),
                             .clear],
                    center: .center, startRadius: 5, endRadius: orbSize * 0.57))
                .frame(width: orbSize, height: orbSize)
                .overlay {
                    Image(systemName: "sparkles")
                        .font(.system(size: orbSymbolSize))
                        .foregroundStyle(.white)
                        .shadow(color: engine.state.currentTier.color, radius: 14)
                }

            ForEach(floats) { f in
                Text("+\(Formatter.short(f.value))")
                    .font(.title3.bold())
                    .foregroundStyle(.white)
                    .offset(x: f.x, y: -(orbSize * 0.5 + 10))
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .id(f.id)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, tapZoneVerticalPad)
        .contentShape(Rectangle())
        .onTapGesture {
            let v = engine.manualTap()
            haptics.tap()
            let floater = Floater(value: v, x: CGFloat.random(in: -40...40))
            withAnimation(.easeOut(duration: 0.7)) {
                floats.append(floater)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                floats.removeAll { $0.id == floater.id }
            }
        }
    }

    private var generatorList: some View {
        VStack(spacing: 8) {
            BuyModePicker()
            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(engine.state.generators) { gen in
                        GeneratorRow(generator: gen)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 16)
            }
        }
    }
}

/// Tiny seeded RNG for deterministic starfield rendering (so the sky doesn't reshuffle every frame).
private struct SeededGenerator {
    var state: UInt64
    init(seed: UInt64) { self.state = seed == 0 ? 1 : seed }
    mutating func next() -> UInt64 {
        state ^= state &<< 13
        state ^= state &>> 7
        state ^= state &<< 17
        return state
    }
    mutating func next01() -> Double {
        Double(next() % 10_000) / 10_000.0
    }
}
