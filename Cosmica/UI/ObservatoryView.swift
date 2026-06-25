import SwiftUI

/// Main game screen — tap zone + generator list.
struct ObservatoryView: View {
    @Environment(GameEngine.self) var engine
    @Environment(HapticsManager.self) var haptics
    @State private var floats: [Floater] = []

    struct Floater: Identifiable { let id = UUID(); let value: Double; let x: CGFloat }

    var body: some View {
        ZStack {
            background
            VStack(spacing: 0) {
                CurrencyBar()
                tierStrip
                tapZone
                generatorList
                BannerAdSlot()
            }
        }
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
                let seed: UInt64 = 0xC05_M1CA
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

    private var tapZone: some View {
        ZStack {
            Circle()
                .fill(RadialGradient(
                    colors: [engine.state.currentTier.color.opacity(0.9),
                             engine.state.currentTier.color.opacity(0.2),
                             .clear],
                    center: .center, startRadius: 5, endRadius: 130))
                .frame(width: 230, height: 230)
                .overlay {
                    Image(systemName: "sparkles")
                        .font(.system(size: 56))
                        .foregroundStyle(.white)
                        .shadow(color: engine.state.currentTier.color, radius: 18)
                }

            ForEach(floats) { f in
                Text("+\(Formatter.short(f.value))")
                    .font(.title3.bold())
                    .foregroundStyle(.white)
                    .offset(x: f.x, y: -80)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .id(f.id)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
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
