import SwiftUI

/// v4.0.4 — the Winter Solstice Trail (see `SolsticeTrail`). A one-line banner on the
/// Observatory (a preview before 13 Dec, progress during the event, hidden after it)
/// that opens this sheet: five goals, a Claim button on each, and the Frost orb.
struct SolsticeBanner: View {
    @Environment(GameEngine.self) private var engine
    @State private var showTrail = false

    static let ice = Color(red: 0.55, green: 0.85, blue: 1.0)

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { ctx in
            let now = ctx.date
            if SolsticeTrail.isUpcoming(now) || SolsticeTrail.isOpen(now) {
                Button { showTrail = true } label: { row(now) }
                    .buttonStyle(.plain)
                    .padding(.horizontal)
                    .padding(.top, 2)
            }
        }
        .sheet(isPresented: $showTrail) {
            SolsticeTrailSheet().presentationDetents([.large])
        }
    }

    private func row(_ now: Date) -> some View {
        let s = engine.state
        let open = SolsticeTrail.isOpen(now)
        let claimed = SolsticeTrail.claimedCount(s)
        let ready = SolsticeStep.allCases.contains { engine.solsticeClaimable($0) }
        let right: String
        if !open {
            right = "Opens in \(Formatter.duration(SolsticeTrail.start.timeIntervalSince(now)))"
        } else if s.solsticeOrbEarned {
            right = "Complete ❄"
        } else {
            right = "\(claimed)/5 · \(Formatter.duration(SolsticeTrail.end.timeIntervalSince(now))) left"
        }
        return HStack(spacing: 10) {
            Image(systemName: "snowflake").foregroundStyle(Self.ice)
            Text("Winter Solstice Trail").font(.subheadline.bold()).foregroundStyle(.white)
            if ready {
                Text("CLAIM").font(.caption2.bold()).foregroundStyle(.black)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(Self.ice, in: Capsule())
            }
            Spacer()
            Text(right).font(.caption.bold()).foregroundStyle(Self.ice).monospacedDigit()
            Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            LinearGradient(colors: [Self.ice.opacity(0.26), Color.blue.opacity(0.12)],
                           startPoint: .leading, endPoint: .trailing),
            in: RoundedRectangle(cornerRadius: 10)
        )
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Self.ice.opacity(0.5), lineWidth: 1))
    }
}

struct SolsticeTrailSheet: View {
    @Environment(GameEngine.self) private var engine
    @Environment(HapticsManager.self) private var haptics
    @Environment(\.dismiss) private var dismiss

    private let ice = SolsticeBanner.ice

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(colors: [Color(red: 0.04, green: 0.06, blue: 0.18), Color(red: 0.10, green: 0.04, blue: 0.22)],
                               startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()
                ScrollView {
                    TimelineView(.periodic(from: .now, by: 1)) { ctx in
                        content(ctx.date)
                    }
                    .padding()
                }
            }
            .navigationTitle("Winter Solstice Trail")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
    }

    @ViewBuilder
    private func content(_ now: Date) -> some View {
        let s = engine.state
        VStack(alignment: .leading, spacing: 14) {
            header(now)
            if SolsticeTrail.isOpen(now) && engine.solsticeStarted {
                ForEach(SolsticeStep.allCases) { step in stepCard(step, s) }
            } else {
                preview
            }
            orbCard(s)
            Text("Goals are sized to your progress when the trail opens and read lifetime counters, so a Big Bang never costs you progress. Goals you finish but don't claim are paid when the event ends.")
                .font(.caption2).foregroundStyle(.secondary)
        }
    }

    private func header(_ now: Date) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: "snowflake").font(.title2).foregroundStyle(ice)
                Text(SolsticeTrail.isOpen(now) ? "The longest night is here" : "Coming December 13")
                    .font(.title3.bold()).foregroundStyle(.white)
            }
            Text(SolsticeTrail.isOpen(now)
                 ? "Ends in \(Formatter.duration(SolsticeTrail.end.timeIntervalSince(now)))"
                 : "Opens in \(Formatter.duration(SolsticeTrail.start.timeIntervalSince(now))) and runs to January 10.")
                .font(.caption).foregroundStyle(ice).monospacedDigit()
            Text("Five winter goals. Each pays a Big Bang's worth of Cosmic Shards. Finish all five for a Challenge Star and the Frost orb, which can only be earned during the event.")
                .font(.subheadline).foregroundStyle(.white.opacity(0.85))
        }
    }

    private var preview: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(SolsticeStep.allCases) { step in
                HStack(spacing: 12) {
                    Image(systemName: step.symbol).foregroundStyle(ice).frame(width: 28)
                    Text(previewTitle(step)).font(.subheadline).foregroundStyle(.white)
                    Spacer()
                }
            }
        }
        .dsCard(.core)
    }

    private func previewTitle(_ step: SolsticeStep) -> String {
        switch step {
        case .dailies:    return "Claim daily rewards on 5 days"
        case .taps:       return "Tap the orb 2,500 times"
        case .bigBangs:   return "Big Bang, sized to how you play"
        case .generators: return "Buy generators, sized to how you play"
        case .bestRun:    return "Beat your best run by ×100"
        }
    }

    private func stepCard(_ step: SolsticeStep, _ s: GameState) -> some View {
        let met = SolsticeTrail.isMet(step, s)
        let claimed = SolsticeTrail.isClaimed(step, s)
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Image(systemName: claimed ? "checkmark.seal.fill" : step.symbol)
                    .font(.title3).foregroundStyle(met ? ice : .white).frame(width: 30)
                Text(SolsticeTrail.title(step, s)).font(.subheadline.bold()).foregroundStyle(.white)
                Spacer()
            }
            if claimed {
                Text("Claimed").font(.caption.bold()).foregroundStyle(.green)
            } else if met {
                Button {
                    if engine.claimSolstice(step) > 0 { haptics.upgrade() }
                } label: {
                    Text("Claim \(Formatter.short(engine.solsticeRewardShards)) ◈")
                        .font(.headline)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .foregroundStyle(.black)
                        .background(LinearGradient(colors: [.white, ice], startPoint: .leading, endPoint: .trailing),
                                    in: RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            } else {
                ProgressView(value: SolsticeTrail.progress(step, s)).tint(ice)
                Text(progressLabel(step, s)).font(.caption).foregroundStyle(.secondary).monospacedDigit()
            }
        }
        .dsCard(.core, highlighted: met && !claimed)
    }

    private func progressLabel(_ step: SolsticeStep, _ s: GameState) -> String {
        let done = SolsticeTrail.doneAmount(step, s), goal = SolsticeTrail.goalAmount(step, s)
        if step == .bestRun { return "This run: \(Formatter.short(done)) of \(Formatter.short(goal)) ✦" }
        return "\(Formatter.count(min(done, goal))) of \(Formatter.count(goal))"
    }

    private func orbCard(_ s: GameState) -> some View {
        HStack(spacing: 14) {
            Circle()
                .fill(RadialGradient(colors: [OrbSkin.frost.core ?? .white, OrbSkin.frost.accent.opacity(0.35)],
                                     center: .center, startRadius: 2, endRadius: 22))
                .frame(width: 44, height: 44)
                .shadow(color: ice.opacity(0.7), radius: 10)
            VStack(alignment: .leading, spacing: 3) {
                Text(s.solsticeOrbEarned ? "Frost orb earned" : "Frost orb").font(.headline).foregroundStyle(.white)
                Text(s.solsticeOrbEarned
                     ? "Pick it in Settings › Tap Orb. Yours to keep."
                     : "Finish all five goals: ★ Challenge Star (+10% earnings, forever) and the Frost orb.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .dsCard(.core, highlighted: s.solsticeOrbEarned)
    }
}
