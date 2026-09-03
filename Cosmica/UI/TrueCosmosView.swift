import SwiftUI

/// The meta-prestige screen. Reached from BigBangView once the player has Absolute
/// Ascended. Trades every Cosmic Shard + tree level + generator + upgrade for permanent
/// Reality Fragments — each fragment is +5% earnings, forever, stacking across every
/// future Cosmos.
struct TrueCosmosView: View {
    @Environment(GameEngine.self) var engine
    @Environment(HapticsManager.self) var haptics

    @State private var showConfirm = false
    @State private var collapseAnim = false

    var body: some View {
        ZStack {
            background
            ScrollView {
                VStack(spacing: 22) {
                    cosmosOrb.padding(.top, 12)
                    fragmentRewardCard
                    permanentPowerCard
                    cosmosCountCard
                    resetSummaryCard
                    if engine.canTrueCosmos {
                        collapseButton
                    } else {
                        lockedCard
                    }
                }
                .padding(.bottom, 32)
            }
        }
        .navigationTitle("True Cosmos")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.black, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .confirmationDialog(
            "Collapse this cosmos?",
            isPresented: $showConfirm,
            titleVisibility: .visible
        ) {
            Button("Collapse (\(engine.availableFragments) fragments)", role: .destructive) {
                triggerCollapse()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Trades every Cosmic Shard, every tree level, every generator, and every upgrade for permanent Reality Fragments. Your Absolute Observer title is kept.")
        }
    }

    private var background: some View {
        ZStack {
            Color.black
            TimelineView(.animation) { ctx in
                let angle = Angle.degrees(ctx.date.timeIntervalSince1970.truncatingRemainder(dividingBy: 90) * 4)
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
                .opacity(0.22)
                .blur(radius: 140)
            }
            .scaleEffect(collapseAnim ? 0.1 : 1)
            .opacity(collapseAnim ? 0 : 1)
            .animation(.easeIn(duration: 1.4), value: collapseAnim)
        }
        .ignoresSafeArea()
    }

    private var cosmosOrb: some View {
        TimelineView(.animation) { ctx in
            let angle = Angle.degrees(ctx.date.timeIntervalSince1970.truncatingRemainder(dividingBy: 40) * 9)
            ZStack {
                Circle()
                    .fill(RadialGradient(
                        colors: [Color(red: 1.0, green: 0.55, blue: 0.90).opacity(0.7), Color(red: 0.55, green: 0.20, blue: 0.95).opacity(0.3), .clear],
                        center: .center, startRadius: 4, endRadius: 160
                    ))
                    .frame(width: 240, height: 240)
                    .blur(radius: 8)
                Image(systemName: "infinity.circle.fill")
                    .font(.system(size: 100, weight: .thin))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color(red: 1.0, green: 0.55, blue: 0.90), Color(red: 0.30, green: 0.90, blue: 1.00), Color(red: 1.0, green: 0.72, blue: 0.20)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
                    .rotationEffect(angle)
                    .shadow(color: Color(red: 0.55, green: 0.20, blue: 0.95).opacity(0.8), radius: 30)
                    .scaleEffect(collapseAnim ? 0.05 : 1)
                    .opacity(collapseAnim ? 0 : 1)
                    .animation(.easeIn(duration: 1.3), value: collapseAnim)
            }
        }
    }

    private var fragmentRewardCard: some View {
        let fragments = engine.availableFragments
        let progress = CosmosCalculator.progressToNextFragment(cosmicShards: engine.state.cosmicShards)
        return VStack(alignment: .leading, spacing: 10) {
            Text("Reality Fragments").font(.headline).foregroundStyle(.white)
            HStack {
                Text("If you Cosmos now").foregroundStyle(.secondary).font(.subheadline)
                Spacer()
                Text("+\(fragments)")
                    .font(.title2.bold())
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color(red: 1.0, green: 0.55, blue: 0.90), Color(red: 0.30, green: 0.90, blue: 1.00)],
                            startPoint: .leading, endPoint: .trailing
                        )
                    )
            }
            ProgressView(value: progress).tint(Color(red: 1.0, green: 0.55, blue: 0.90))
            HStack {
                Text("Current: \(Formatter.short(engine.state.cosmicShards)) ◈")
                    .font(.caption).foregroundStyle(.secondary).monospacedDigit()
                Spacer()
                Text("Next fragment: \(Formatter.short(CosmosCalculator.nextFragmentThreshold(cosmicShards: engine.state.cosmicShards))) ◈")
                    .font(.caption).foregroundStyle(.secondary).monospacedDigit()
            }
            Text("Each Fragment permanently multiplies earnings by +5%. Fragments never reset.")
                .font(.caption2).foregroundStyle(.secondary)
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal)
    }

    private var permanentPowerCard: some View {
        let mult = engine.state.realityFragmentMultiplier
        return VStack(alignment: .leading, spacing: 10) {
            Text("Permanent Power").font(.headline).foregroundStyle(.white)
            HStack {
                Image(systemName: "infinity")
                    .font(.title2)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color(red: 1.0, green: 0.55, blue: 0.90), Color(red: 0.30, green: 0.90, blue: 1.00)],
                            startPoint: .leading, endPoint: .trailing
                        )
                    )
                    .frame(width: 40)
                VStack(alignment: .leading) {
                    Text("×\(String(format: "%.2f", mult))")
                        .font(.title3.bold())
                        .foregroundStyle(.white)
                        .monospacedDigit()
                    Text("from \(Int(engine.state.realityFragments)) Reality Fragments")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal)
    }

    private var cosmosCountCard: some View {
        let count = engine.state.cosmosCount
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "sparkle").foregroundStyle(.orange)
                Text("Cosmoi Collapsed")
                    .font(.headline).foregroundStyle(.white)
                Spacer()
                Text("\(count)")
                    .font(.title2.bold())
                    .foregroundStyle(.white)
                    .monospacedDigit()
            }
            if count == 0 {
                Text("Your first Cosmos awaits.")
                    .font(.caption).foregroundStyle(.secondary)
            } else if count == 1 {
                Text("Realm-Walker. One universe collapsed and reborn.")
                    .font(.caption).foregroundStyle(.secondary)
            } else if count < 10 {
                Text("The pattern is becoming clear.")
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                Text("The pattern is you.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal)
    }

    private var resetSummaryCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "arrow.counterclockwise.circle.fill").foregroundStyle(.red.opacity(0.75))
                Text("What resets").font(.subheadline.bold()).foregroundStyle(.white)
            }
            resetRow(icon: "diamond.fill", text: "All Cosmic Shards")
            resetRow(icon: "sparkles",     text: "All Stardust and lifetime record")
            resetRow(icon: "wand.and.stars", text: "All Cosmic Tree levels")
            resetRow(icon: "scope",        text: "All generators and upgrades")
            HStack {
                Image(systemName: "checkmark.seal.fill").foregroundStyle(.green)
                Text("What survives").font(.subheadline.bold()).foregroundStyle(.white)
            }
            .padding(.top, 6)
            resetRow(icon: "infinity.circle.fill", text: "Reality Fragments (+5% each, permanent)")
            resetRow(icon: "sparkle",              text: "Absolute Observer title")
            resetRow(icon: "cart.fill",            text: "IAP purchases (Remove Ads, etc.)")
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal)
    }

    private func resetRow(icon: String, text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon).foregroundStyle(.secondary).frame(width: 22)
            Text(text).font(.caption).foregroundStyle(.secondary)
            Spacer()
        }
    }

    private var collapseButton: some View {
        Button { showConfirm = true } label: {
            Text("Collapse the Cosmos — claim \(engine.availableFragments) fragments")
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
                .shadow(color: Color(red: 1.0, green: 0.55, blue: 0.90).opacity(0.5), radius: 16)
        }
        .padding(.horizontal)
    }

    private var lockedCard: some View {
        VStack(spacing: 6) {
            if !engine.state.hasAbsoluteAscended {
                Text("Reach Absolute Observer to unlock True Cosmos")
                    .font(.subheadline).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            } else {
                Text("Need \(Formatter.short(CosmosCalculator.firstCosmosThreshold)) ◈ Cosmic Shards for your first Cosmos")
                    .font(.subheadline).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Text("Current: \(Formatter.short(engine.state.cosmicShards)) ◈")
                    .font(.caption).foregroundStyle(.secondary).monospacedDigit()
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal)
    }

    private func triggerCollapse() {
        withAnimation { collapseAnim = true }
        haptics.bigBang()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
            _ = engine.trueCosmos()
            withAnimation { collapseAnim = false }
        }
    }
}
