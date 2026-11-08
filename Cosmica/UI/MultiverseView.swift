import SwiftUI

/// v3.4 — the third prestige layer. Reached from TrueCosmosView (and the Big
/// Bang tab once open). Trades every Reality Fragment, plus everything a True
/// Cosmos resets, for permanent Void Sparks; sparks also buy the Void Wonders.
struct MultiverseView: View {
    @Environment(GameEngine.self) var engine
    @Environment(HapticsManager.self) var haptics

    @State private var showConfirm = false
    @State private var collapseAnim = false

    private static let violet = Color(red: 0.55, green: 0.45, blue: 1.00)
    private static let ember = Color(red: 1.00, green: 0.48, blue: 0.27)

    var body: some View {
        ZStack {
            background
            ScrollView {
                VStack(spacing: 22) {
                    voidOrb.padding(.top, 12)
                    sparkRewardCard
                    permanentPowerCard
                    resetSummaryCard
                    if engine.canCollapseMultiverse {
                        collapseButton
                    } else {
                        lockedCard
                    }
                    if engine.state.multiverseCount > 0 {
                        voidWondersSection
                    }
                }
                .padding(.bottom, 32)
            }
        }
        .navigationTitle("Multiverse")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.black, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .confirmationDialog("Collapse the multiverse?", isPresented: $showConfirm, titleVisibility: .visible) {
            Button("Collapse (\(Formatter.count(engine.availableSparks)) Void Sparks)", role: .destructive) {
                triggerCollapse()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Trades every Reality Fragment, Cosmic Shard, tree level, generator and upgrade for permanent Void Sparks. Wonders, achievements, challenge stars and purchases are kept.")
        }
    }

    private var background: some View {
        ZStack {
            Color.black
            RadialGradient(colors: [Self.violet.opacity(0.35), Self.ember.opacity(0.10), .clear],
                           center: .center, startRadius: 5, endRadius: 420)
                .scaleEffect(collapseAnim ? 0.1 : 1)
                .opacity(collapseAnim ? 0 : 1)
                .animation(.easeIn(duration: 1.4), value: collapseAnim)
        }
        .ignoresSafeArea()
    }

    private var voidOrb: some View {
        TimelineView(.animation) { ctx in
            let angle = Angle.degrees(ctx.date.timeIntervalSince1970.truncatingRemainder(dividingBy: 60) * -6)
            ZStack {
                Circle()
                    .fill(RadialGradient(colors: [.black, Self.violet.opacity(0.6), .clear],
                                         center: .center, startRadius: 20, endRadius: 140))
                    .frame(width: 230, height: 230)
                Circle()
                    .strokeBorder(AngularGradient(colors: [Self.ember, Self.violet, Self.ember], center: .center),
                                  lineWidth: 6)
                    .frame(width: 130, height: 130)
                    .rotationEffect(angle)
                    .shadow(color: Self.ember.opacity(0.7), radius: 20)
            }
            .scaleEffect(collapseAnim ? 0.05 : 1)
            .opacity(collapseAnim ? 0 : 1)
            .animation(.easeIn(duration: 1.3), value: collapseAnim)
        }
    }

    private var sparkRewardCard: some View {
        let f = engine.state.realityFragments
        return card {
            Text("Void Sparks").font(.headline).foregroundStyle(.white)
            HStack {
                Text("If you collapse now").foregroundStyle(.secondary).font(.subheadline)
                Spacer()
                Text("+\(Formatter.count(engine.availableSparks))")
                    .font(.title2.bold())
                    .foregroundStyle(LinearGradient(colors: [Self.violet, Self.ember], startPoint: .leading, endPoint: .trailing))
            }
            ProgressView(value: MultiverseCalculator.progressToNextSpark(realityFragments: f)).tint(Self.violet)
            HStack {
                Text("Fragments: \(Formatter.short(f))").font(.caption).foregroundStyle(.secondary).monospacedDigit()
                Spacer()
                Text("Next spark: \(Formatter.short(MultiverseCalculator.nextSparkThreshold(realityFragments: f)))")
                    .font(.caption).foregroundStyle(.secondary).monospacedDigit()
            }
            Text("Each unspent Void Spark adds +\(Int(MultiverseCalculator.stardustPerSpark * 100))% Stardust, forever. Sparks also raise the Reality Fragments every True Cosmos pays: ×\(String(format: "%.1f", engine.state.voidFragmentMultiplier)) right now (it grows with the square root of your sparks). Expect a dip after a big collapse: it takes a few cosmoi to climb past where you were.")
                .font(.caption2).foregroundStyle(.secondary)
        }
    }

    private var permanentPowerCard: some View {
        card {
            Text("Permanent Power").font(.headline).foregroundStyle(.white)
            row("Stardust", Formatter.multiplier(engine.state.voidSparkMultiplier))
            row("Reality Fragments", Formatter.multiplier(engine.state.voidFragmentMultiplier))
            row("Void Sparks held", Formatter.count(engine.state.voidSparks))
            row("Multiverses collapsed", "\(engine.state.multiverseCount)")
        }
    }

    private var resetSummaryCard: some View {
        card {
            Label("What resets", systemImage: "arrow.counterclockwise.circle.fill")
                .font(.subheadline.bold()).foregroundStyle(.white)
            bullet("All Reality Fragments")
            bullet("Everything a True Cosmos resets: shards, tree, generators, upgrades")
            Label("What survives", systemImage: "checkmark.seal.fill")
                .font(.subheadline.bold()).foregroundStyle(.white)
                .padding(.top, 6)
            bullet("Void Sparks and Void Wonders")
            bullet("Cosmic Wonders and your cosmos count")
            bullet("Achievements, challenge stars, Absolute Observer, purchases")
        }
    }

    private var collapseButton: some View {
        Button { showConfirm = true } label: {
            Text("Collapse the Multiverse — claim \(Formatter.count(engine.availableSparks)) sparks")
                .font(.headline)
                .frame(maxWidth: .infinity, minHeight: 54)
                .background(LinearGradient(colors: [Self.violet, Self.ember], startPoint: .leading, endPoint: .trailing),
                            in: RoundedRectangle(cornerRadius: 14))
                .foregroundStyle(.white)
                .shadow(color: Self.violet.opacity(0.5), radius: 16)
        }
        .padding(.horizontal)
    }

    private var lockedCard: some View {
        card {
            if !engine.multiverseUnlocked {
                Text("Collapse \(MultiverseCalculator.cosmosRequired) cosmoi to open the Multiverse (\(engine.state.cosmosCount) so far).")
                    .font(.subheadline).foregroundStyle(.secondary)
                ProgressView(value: Double(min(engine.state.cosmosCount, MultiverseCalculator.cosmosRequired)),
                             total: Double(MultiverseCalculator.cosmosRequired))
                    .tint(Self.violet)
            } else {
                Text("Hold \(Formatter.short(MultiverseCalculator.firstFragments)) Reality Fragments to collapse for Void Sparks.")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
        }
    }

    private var voidWondersSection: some View {
        VStack(spacing: 14) {
            HStack {
                Text("Void Wonders").font(.headline).foregroundStyle(.white)
                Spacer()
                Text("\(Formatter.count(engine.state.voidSparks)) sparks")
                    .font(.caption).foregroundStyle(.secondary).monospacedDigit()
            }
            .padding(.horizontal)
            Text("Spent sparks stop adding their Stardust bonus. Wonders are permanent.")
                .font(.caption2).foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
            ForEach(VoidWonderCatalog.all) { w in
                VoidWonderRow(wonder: w) {
                    if engine.buildVoidWonder(id: w.id) { haptics.skillUnlock() }
                }
                .padding(.horizontal)
            }
        }
    }

    private func card<C: View>(@ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 10) { content() }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
            .padding(.horizontal)
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).font(.subheadline).foregroundStyle(.secondary)
            Spacer()
            Text(value).font(.subheadline.bold()).foregroundStyle(.white).monospacedDigit()
        }
    }

    private func bullet(_ text: String) -> some View {
        Text("• " + text).font(.caption).foregroundStyle(.secondary)
    }

    private func triggerCollapse() {
        withAnimation { collapseAnim = true }
        haptics.bigBang()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
            _ = engine.multiverseCollapse()
            withAnimation { collapseAnim = false }
        }
    }
}

private struct VoidWonderRow: View {
    @Environment(GameEngine.self) private var engine
    let wonder: VoidWonder
    let onBuild: () -> Void

    var body: some View {
        let level = engine.state.wonderLevel(wonder.id)
        let built = level > 0
        let cost = engine.voidWonderCost(wonder.id)
        let gateOk = engine.state.multiverseCount >= wonder.multiverseRequired
        let sparksOk = cost.map { engine.state.voidSparks >= $0 } ?? false
        let canBuy = gateOk && sparksOk
        let color = Color(voidHex: wonder.colorHex)

        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(color.opacity(built ? 0.9 : 0.35)).frame(width: 46, height: 46)
                    Image(systemName: built ? wonder.symbol : "lock.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(built ? .white : .secondary)
                }
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(wonder.title).font(.headline).foregroundStyle(.white)
                        if built && wonder.maxLevel != 1 {
                            Text("Lv \(level)").font(.caption.bold()).foregroundStyle(color)
                        }
                    }
                    Text(wonder.effect(atLevel: level)).font(.caption).foregroundStyle(color)
                }
                Spacer()
                if built && cost == nil {
                    Image(systemName: "checkmark.seal.fill").font(.title3).foregroundStyle(.green)
                }
            }
            Text(wonder.flavor).font(.caption2).italic().foregroundStyle(.secondary)
            if let cost {
                if built {
                    Text("Next: \(wonder.effect(atLevel: level + 1))").font(.caption2).foregroundStyle(.secondary)
                }
                HStack(spacing: 8) {
                    if !gateOk {
                        pill("\(engine.state.multiverseCount) / \(wonder.multiverseRequired) multiverses", ok: false)
                    }
                    pill("\(Formatter.count(cost)) sparks", ok: sparksOk)
                    Spacer()
                }
                Button(action: onBuild) {
                    Text(canBuy ? (built ? "Upgrade to Lv \(level + 1)" : "Build") : "Locked")
                        .font(.subheadline.bold())
                        .frame(maxWidth: .infinity, minHeight: 40)
                        .background(canBuy ? color : Color.gray.opacity(0.25), in: RoundedRectangle(cornerRadius: 10))
                        .foregroundStyle(canBuy ? .white : .secondary)
                }
                .disabled(!canBuy)
            }
        }
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
    }

    private func pill(_ text: String, ok: Bool) -> some View {
        Text(text).font(.caption2).monospacedDigit()
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background((ok ? Color.green : Color.red).opacity(0.18), in: Capsule())
            .foregroundStyle(ok ? .green : .red)
    }
}

private extension Color {
    init(voidHex hex: String) {
        var v: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&v)
        self.init(red: Double((v >> 16) & 0xFF) / 255, green: Double((v >> 8) & 0xFF) / 255, blue: Double(v & 0xFF) / 255)
    }
}
