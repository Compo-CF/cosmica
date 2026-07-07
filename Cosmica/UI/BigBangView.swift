import SwiftUI

struct BigBangView: View {
    @Environment(GameEngine.self) var engine
    @Environment(HapticsManager.self) var haptics

    @State private var showConfirm = false
    @State private var collapseAnim = false

    var body: some View {
        NavigationStack {
            ZStack {
                background
                ScrollView {
                    VStack(spacing: 22) {
                        CurrencyBar().background(.clear)
                        prestigeOrb
                        statsCard
                        tierCard
                        cosmicTreeLink
                        if engine.canPrestige {
                            bigBangButton
                        } else {
                            requirementCard
                        }
                    }
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle("Big Bang")
            .toolbarBackground(Color.black, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .confirmationDialog(
                "Reset the universe?",
                isPresented: $showConfirm,
                titleVisibility: .visible
            ) {
                Button("Big Bang (\(engine.availableShards) ◈)", role: .destructive) {
                    triggerBigBang()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Resets generators and stardust. Cosmic Shards, tier, and achievements are kept.")
            }
        }
    }

    private var background: some View {
        ZStack {
            Color.black
            RadialGradient(
                colors: [Color.purple.opacity(0.5), .clear],
                center: .center, startRadius: 5, endRadius: 380
            )
            .scaleEffect(collapseAnim ? 0.1 : 1)
            .opacity(collapseAnim ? 0 : 1)
            .animation(.easeIn(duration: 1.5), value: collapseAnim)
        }
        .ignoresSafeArea()
    }

    private var prestigeOrb: some View {
        ZStack {
            Circle()
                .fill(RadialGradient(colors: [.purple, .indigo, .black], center: .center, startRadius: 4, endRadius: 110))
                .frame(width: 200, height: 200)
                .shadow(color: .purple, radius: 30)
                .scaleEffect(collapseAnim ? 0.05 : 1)
                .animation(.easeIn(duration: 1.4), value: collapseAnim)
            Image(systemName: "sparkles")
                .font(.system(size: 50))
                .foregroundStyle(.white)
                .opacity(collapseAnim ? 0 : 1)
        }
        .padding(.top, 16)
    }

    private var statsCard: some View {
        let lifetime = engine.state.lifetimeStardust
        let progress = PrestigeCalculator.progressToNextShard(lifetimeStardust: lifetime)
        return VStack(alignment: .leading, spacing: 10) {
            Text("Prestige Reward")
                .font(.headline)
                .foregroundStyle(.white)
            HStack {
                Text("If you Big Bang now").foregroundStyle(.secondary).font(.subheadline)
                Spacer()
                Text("+\(engine.availableShards) ◈")
                    .font(.title2.bold())
                    .foregroundStyle(.cyan)
            }
            ProgressView(value: progress)
                .tint(.cyan)
            HStack {
                Text("Next shard:").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Text(Formatter.short(PrestigeCalculator.nextShardThreshold(lifetimeStardust: lifetime)) + " ✦ lifetime")
                    .font(.caption).foregroundStyle(.secondary).monospacedDigit()
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal)
    }

    private var tierCard: some View {
        let tier = engine.state.currentTier
        return VStack(alignment: .leading, spacing: 10) {
            Text("Current Tier")
                .font(.headline)
                .foregroundStyle(.white)
            HStack {
                Image(systemName: tier.symbol)
                    .font(.title)
                    .foregroundStyle(tier.color)
                    .frame(width: 44)
                VStack(alignment: .leading) {
                    Text(tier.title).font(.title3.bold()).foregroundStyle(.white)
                    Text("×\(String(format: "%.2f", tier.multiplier)) permanent earnings").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
            }
            if let next = tier.next() {
                let progress = (engine.state.lifetimeStardust - tier.threshold) / (next.threshold - tier.threshold)
                ProgressView(value: min(max(progress, 0), 1)).tint(tier.color)
                Text("Next: \(next.title) at \(Formatter.short(next.threshold)) ✦ lifetime")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("Maximum tier reached.").font(.caption).foregroundStyle(tier.color)
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal)
    }

    private var cosmicTreeLink: some View {
        NavigationLink { CosmicTreeView() } label: {
            HStack {
                Image(systemName: "circle.hexagongrid.fill").foregroundStyle(.cyan)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Cosmic Tree").font(.headline).foregroundStyle(.white)
                    Text("Spend \(Formatter.short(engine.state.cosmicShards)) ◈ Cosmic Shards on permanent upgrades")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(.secondary)
            }
            .padding()
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
            .padding(.horizontal)
        }
    }

    private var bigBangButton: some View {
        Button { showConfirm = true } label: {
            Text("Big Bang — claim \(engine.availableShards) ◈")
                .font(.headline)
                .frame(maxWidth: .infinity, minHeight: 54)
                .background(
                    LinearGradient(colors: [.purple, .indigo], startPoint: .leading, endPoint: .trailing),
                    in: RoundedRectangle(cornerRadius: 14)
                )
                .foregroundStyle(.white)
        }
        .padding(.horizontal)
    }

    private var requirementCard: some View {
        VStack(spacing: 6) {
            Text("Reach \(Formatter.short(PrestigeCalculator.threshold)) ✦ lifetime to unlock Big Bang")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal)
    }

    private func triggerBigBang() {
        withAnimation { collapseAnim = true }
        haptics.bigBang()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            _ = engine.bigBang()
            withAnimation { collapseAnim = false }
        }
    }
}
