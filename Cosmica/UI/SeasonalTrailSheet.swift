import SwiftUI

/// v4.0.4/4.0.5 — Seasonal Trails (see `SeasonalTrails`). A one-line banner on the Observatory
/// (a preview of the next trail before it opens, progress while it runs, hidden when none is
/// left) that opens a sheet: five goals, a Claim button on each, and the trail's orb.
struct SeasonalTrailBanner: View {
    @Environment(GameEngine.self) private var engine
    @State private var shown: TrailEvent?

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { ctx in
            // Ad capture hides the dated banner so the footage stays evergreen (AdClipMode.swift).
            if !AdClipMode.isActive, let ev = SeasonalTrails.featured(ctx.date) {
                Button { shown = ev } label: { row(ev, ctx.date) }
                    .buttonStyle(.plain)
                    .padding(.horizontal)
                    .padding(.top, 2)
            }
        }
        .sheet(item: $shown) { ev in
            SeasonalTrailSheet(event: ev).presentationDetents([.large])
        }
    }

    private func row(_ ev: TrailEvent, _ now: Date) -> some View {
        let s = engine.state
        let tint = ev.color
        let running = engine.trailEvent?.id == ev.id
        let open = ev.isOpen(now)
        let ready = running && ev.steps.contains { engine.trailClaimable($0) }
        let right: String
        if !open {
            right = "Opens in \(Formatter.duration(ev.start.timeIntervalSince(now)))"
        } else if s.trailOrbsEarned.contains(ev.id) {
            right = "Complete \u{2713}"
        } else {
            right = "\(running ? SeasonalTrails.claimedCount(ev, s) : 0)/\(ev.steps.count) · \(Formatter.duration(ev.end.timeIntervalSince(now))) left"
        }
        return HStack(spacing: 10) {
            Image(systemName: ev.symbol).foregroundStyle(tint)
            Text(ev.title).font(.subheadline.bold()).foregroundStyle(.white)
            if ready {
                Text("CLAIM").font(.caption2.bold()).foregroundStyle(.black)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(tint, in: Capsule())
            }
            Spacer()
            Text(right).font(.caption.bold()).foregroundStyle(tint).monospacedDigit()
            Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            LinearGradient(colors: [tint.opacity(0.26), tint.opacity(0.08)], startPoint: .leading, endPoint: .trailing),
            in: RoundedRectangle(cornerRadius: 10)
        )
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(tint.opacity(0.5), lineWidth: 1))
    }
}

extension TrailEvent {
    var color: Color { Color(red: tint.r, green: tint.g, blue: tint.b) }
    var orb: OrbSkin { OrbSkin(rawValue: orbId) ?? .tier }
}

struct SeasonalTrailSheet: View {
    let event: TrailEvent
    @Environment(GameEngine.self) private var engine
    @Environment(HapticsManager.self) private var haptics
    @Environment(\.dismiss) private var dismiss

    private var tint: Color { event.color }

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
            .navigationTitle(event.title)
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
            if event.isOpen(now) && engine.trailEvent?.id == event.id {
                ForEach(event.steps) { step in stepCard(step, s) }
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
                Image(systemName: event.symbol).font(.title2).foregroundStyle(tint)
                Text(event.isOpen(now) ? event.openHeadline : event.comingHeadline)
                    .font(.title3.bold()).foregroundStyle(.white)
            }
            Text(event.isOpen(now)
                 ? "Ends in \(Formatter.duration(event.end.timeIntervalSince(now)))"
                 : "Opens in \(Formatter.duration(event.start.timeIntervalSince(now))) and \(event.runsTo)")
                .font(.caption).foregroundStyle(tint).monospacedDigit()
            Text(event.pitch).font(.subheadline).foregroundStyle(.white.opacity(0.85))
        }
    }

    private var preview: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(event.steps) { step in
                HStack(spacing: 12) {
                    Image(systemName: step.symbol).foregroundStyle(tint).frame(width: 28)
                    Text(SeasonalTrails.previewTitle(step, event)).font(.subheadline).foregroundStyle(.white)
                    Spacer()
                }
            }
        }
        .dsCard(.core)
    }

    private func stepCard(_ step: TrailStep, _ s: GameState) -> some View {
        let met = SeasonalTrails.isMet(step, s)
        let claimed = SeasonalTrails.isClaimed(step, s)
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Image(systemName: claimed ? "checkmark.seal.fill" : step.symbol)
                    .font(.title3).foregroundStyle(met ? tint : .white).frame(width: 30)
                Text(SeasonalTrails.title(step, s)).font(.subheadline.bold()).foregroundStyle(.white)
                Spacer()
            }
            if claimed {
                Text("Claimed").font(.caption.bold()).foregroundStyle(.green)
            } else if met {
                Button {
                    if engine.claimTrail(step) > 0 { haptics.upgrade() }
                } label: {
                    Text("Claim \(Formatter.short(engine.trailRewardShards)) ◈")
                        .font(.headline)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .foregroundStyle(.black)
                        .background(LinearGradient(colors: [.white, tint], startPoint: .leading, endPoint: .trailing),
                                    in: RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            } else {
                ProgressView(value: SeasonalTrails.progress(step, s)).tint(tint)
                Text(progressLabel(step, s)).font(.caption).foregroundStyle(.secondary).monospacedDigit()
            }
        }
        .dsCard(.core, highlighted: met && !claimed)
    }

    private func progressLabel(_ step: TrailStep, _ s: GameState) -> String {
        let done = SeasonalTrails.doneAmount(step, s), goal = SeasonalTrails.goalAmount(step, s)
        if step == .bestRun { return "This run: \(Formatter.short(done)) of \(Formatter.short(goal)) ✦" }
        return "\(Formatter.count(min(done, goal))) of \(Formatter.count(goal))"
    }

    private func orbCard(_ s: GameState) -> some View {
        let earned = s.trailOrbsEarned.contains(event.id)
        let orb = event.orb
        return HStack(spacing: 14) {
            Circle()
                .fill(RadialGradient(colors: [orb.core ?? .white, orb.accent.opacity(0.35)],
                                     center: .center, startRadius: 2, endRadius: 22))
                .frame(width: 44, height: 44)
                .shadow(color: tint.opacity(0.7), radius: 10)
            VStack(alignment: .leading, spacing: 3) {
                Text(earned ? "\(event.orbName) orb earned" : "\(event.orbName) orb").font(.headline).foregroundStyle(.white)
                Text(earned
                     ? "Pick it in Settings › Tap Orb. Yours to keep."
                     : "Finish all five goals: ★ Challenge Star (+10% earnings, forever) and the \(event.orbName) orb.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .dsCard(.core, highlighted: earned)
    }
}
