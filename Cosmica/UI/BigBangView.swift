import SwiftUI

struct BigBangView: View {
    @Environment(GameEngine.self) var engine
    @Environment(HapticsManager.self) var haptics
    @Environment(ReviewPrompter.self) var reviewPrompter
    @Environment(IAPManager.self) var iap
    @Environment(AutomationManager.self) var automation
    @Environment(AdManager.self) var ads

    @State private var showConfirm = false
    @State private var collapseAnim = false
    @State private var showBoostNudge = false

    /// v3.0 Phase 3 — Auto-Big-Bang threshold options. Double to match the
    /// post-v2.1.1 shard type.
    private let autoBangThresholdOptions: [Double] = [10, 100, 1_000, 10_000, 100_000, 1_000_000]

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
                        achievementsLink
                        if engine.state.hasAbsoluteAscended {
                            trueCosmosLink
                        }
                        if engine.state.cosmosCount >= 1 {
                            wondersLink
                        }
                        if automation.isActive {
                            autoBigBangCard
                        }
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
                Button("Big Bang (\(Formatter.short(engine.availableShards)) ◈)", role: .destructive) {
                    triggerBigBang()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Resets generators and stardust. Cosmic Shards, tier, and achievements are kept.")
            }
            .sheet(isPresented: $showBoostNudge) {
                BoostNudgeSheet()
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
                Text("+\(Formatter.short(engine.availableShards)) ◈")
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
                HStack(spacing: 6) {
                    Image(systemName: "infinity.circle.fill")
                        .font(.caption)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color(red: 1.0, green: 0.55, blue: 0.90), Color(red: 0.30, green: 0.90, blue: 1.00), Color(red: 1.0, green: 0.72, blue: 0.20)],
                                startPoint: .leading, endPoint: .trailing
                            )
                        )
                    Text(engine.state.hasAbsoluteAscended ? "Absolute Observer — the ladder is complete." : "Maximum tier reached.")
                        .font(.caption).foregroundStyle(tier.color)
                }
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

    /// Always-visible achievements board. Populates as the player plays; opening it
    /// early shows all 25 goals with progress bars.
    private var achievementsLink: some View {
        NavigationLink { AchievementsView() } label: {
            HStack {
                Image(systemName: "rosette").foregroundStyle(.orange)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Achievements").font(.headline).foregroundStyle(.white)
                    Text("\(engine.state.unlockedAchievementIds.count) / \(AchievementCatalog.all.count) unlocked  ·  ×\(String(format: "%.3f", engine.state.achievementMultiplier)) permanent")
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

    /// Endgame Wonders. Only shown once the player has completed at least one True Cosmos
    /// (so the intro doesn't leak the meta-loop before it's earned).
    private var wondersLink: some View {
        NavigationLink { WondersView() } label: {
            HStack {
                Image(systemName: "building.columns.fill").foregroundStyle(.pink)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Cosmic Wonders").font(.headline).foregroundStyle(.white)
                    Text("\(engine.state.builtWonderIds.count) / \(WondersCatalog.all.count) built  ·  permanent across every reset")
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

    /// Meta-prestige entry point. Only shown once the player has crossed Absolute
    /// (matches the `.hasAbsoluteAscended` gate in the parent VStack).
    private var trueCosmosLink: some View {
        NavigationLink { TrueCosmosView() } label: {
            HStack {
                Image(systemName: "infinity.circle.fill")
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color(red: 1.0, green: 0.55, blue: 0.90), Color(red: 0.30, green: 0.90, blue: 1.00), Color(red: 1.0, green: 0.72, blue: 0.20)],
                            startPoint: .leading, endPoint: .trailing
                        )
                    )
                VStack(alignment: .leading, spacing: 2) {
                    Text("True Cosmos").font(.headline).foregroundStyle(.white)
                    if engine.state.cosmosCount > 0 {
                        Text("\(engine.state.cosmosCount) cosmos collapsed  ·  ×\(String(format: "%.2f", engine.state.realityFragmentMultiplier)) permanent")
                            .font(.caption).foregroundStyle(.secondary)
                    } else {
                        Text("Collapse the universe for permanent Reality Fragments")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(.secondary)
            }
            .padding()
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
            .padding(.horizontal)
        }
    }

    // v3.0 Phase 3 — Auto-Big-Bang panel. Only visible when Automation Core is
    // active. Toggle + threshold picker; when armed, prestige fires on the tick
    // that `engine.availableShards >= threshold` (rate-limited to one per 30s).
    private var autoBigBangCard: some View {
        let enabled = engine.state.autoBigBangEnabled
        let threshold = engine.state.autoBigBangThreshold
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "burst.fill")
                    .foregroundStyle(.orange)
                Text("Auto-Big-Bang")
                    .font(.headline)
                    .foregroundStyle(.white)
                Spacer()
                Toggle("", isOn: Binding(
                    get: { engine.state.autoBigBangEnabled },
                    set: { engine.setAutoBigBangEnabled($0); haptics.purchase() }
                ))
                .labelsHidden()
                .tint(.orange)
            }
            if enabled {
                Menu {
                    ForEach(autoBangThresholdOptions, id: \.self) { t in
                        Button {
                            engine.setAutoBigBangThreshold(t)
                        } label: {
                            HStack {
                                Text("\(Formatter.short(t)) ◈")
                                if t == threshold {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack {
                        Text("Fire when Big Bang grants")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("≥ \(Formatter.short(threshold)) ◈")
                            .font(.subheadline.bold())
                            .foregroundStyle(.cyan)
                            .monospacedDigit()
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 10)
                    .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
                }
                Text(autoBangStatusText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("Off — Big Bang stays a manual action.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal)
    }

    /// Live status line under the threshold picker. Tells the player what's
    /// happening right now: waiting, ready to fire, or recently fired.
    private var autoBangStatusText: String {
        let available = engine.availableShards
        let threshold = engine.state.autoBigBangThreshold
        if available >= threshold {
            return "Ready — firing on the next tick."
        }
        if let last = engine.state.lastAutoBangAt {
            let elapsed = Date().timeIntervalSince(last)
            if elapsed < 3600 {
                return "Last auto-fire: \(Formatter.duration(elapsed)) ago. Waiting for \(Formatter.short(threshold - available)) more ◈."
            }
        }
        return "Waiting for \(Formatter.short(threshold - available)) more ◈."
    }

    private var bigBangButton: some View {
        Button { showConfirm = true } label: {
            Text("Big Bang — claim \(Formatter.short(engine.availableShards)) ◈")
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
            let shards = engine.bigBang()
            withAnimation { collapseAnim = false }
            // Happy-moment: a Big Bang that actually paid out something meaningful.
            // Delay one full second so the confetti/haptics finish first — nothing
            // ruins a review prompt like landing it on top of an animation.
            if shards >= 10 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    reviewPrompter.maybePrompt(reason: "big_bang")
                }
            }
            // v2.1: IAP nudge. Only fires on the 3rd, 7th, 15th prestige, only if
            // the player has no active boost, no Remove Ads, and hasn't seen the
            // nudge in 7 days. Rating prompt (above) and nudge (below) don't
            // conflict — the rating prompt uses the iOS system sheet, our nudge
            // is a SwiftUI sheet. But we prefer rating first, so nudge waits ~2s.
            //
            // v3.0.x: on prestiges where the boost nudge ISN'T firing, we try to
            // show an interstitial ad instead — mutually exclusive so we never
            // double-hit players in one Big Bang cycle. Remove Ads owners always
            // skip. AdManager enforces a 3-min rate limit internally, so tight
            // Big Bang sessions don't spam ads.
            let noActiveBoost = (engine.state.adBoostExpiresAt.map { $0 < Date() } ?? true)
            let isBoostNudgePrestige = [3, 7, 15].contains(engine.state.prestigeCount)
                && iap.boostNudgeEligible
                && noActiveBoost
            if isBoostNudgePrestige {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    iap.recordBoostNudgeShown()
                    showBoostNudge = true
                }
            } else if !iap.removeAdsOwned && ads.interstitialReady {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                    if let root = UIApplication.shared.topMostViewController() {
                        ads.showInterstitialIfReady(from: root)
                    }
                }
            }
        }
    }
}
