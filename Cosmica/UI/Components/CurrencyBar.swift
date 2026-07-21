import SwiftUI

/// The always-visible header — biggest thing on the Observatory screen.
///
/// v1.2 redesign: the ✦/s rate is now front-and-center rather than tucked in a
/// corner. Layout is a two-tier hero card: on top, a large monospaced Stardust
/// total; underneath, a bold green rate pill with a pulsing dot indicator that
/// makes the "still ticking" feel visceral. Cosmic Shards + boost badges sit
/// as smaller chips on the right so they don't compete for attention.
struct CurrencyBar: View {
    @Environment(GameEngine.self) var engine

    var body: some View {
        let tier = engine.state.currentTier
        let rate = engine.state.stardustPerSecond
        VStack(spacing: 8) {
            // Row 1 — Stardust hero + shards chip
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Image(systemName: "sparkles").foregroundStyle(tier.color)
                Text(Formatter.short(engine.state.stardust))
                    .font(.system(size: 34, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .animation(.snappy, value: engine.state.stardust)
                Text("✦")
                    .font(.title3.bold())
                    .foregroundStyle(.white.opacity(0.65))
                Spacer()
                shardsChip
            }
            // Row 2 — rate pill + optional boost badge
            HStack(spacing: 8) {
                ratePill(rate: rate, color: tier.color)
                if engine.state.adBoostMultiplier > 1.0 {
                    boostBadge
                }
                Spacer()
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 10)
        .background(.ultraThinMaterial)
        .overlay(alignment: .bottom) {
            Rectangle().fill(tier.color.opacity(0.3)).frame(height: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(Formatter.short(engine.state.stardust)) Stardust, earning \(Formatter.short(rate)) per second, \(Formatter.short(engine.state.cosmicShards)) Cosmic Shards")
    }

    // MARK: - Rate pill

    /// The big animated "+X ✦/s" pill. A once-per-second pulsing dot signals
    /// the tick is alive without shouting; the +/second copy is the actual
    /// prominence lift the player was asking for.
    private func ratePill(rate: Double, color: Color) -> some View {
        HStack(spacing: 8) {
            PulsingDot(color: .green)
            Text("+\(Formatter.short(rate))")
                .font(.system(size: 20, weight: .heavy, design: .rounded))
                .foregroundStyle(.green)
                .monospacedDigit()
                .contentTransition(.numericText())
                .animation(.snappy, value: rate)
            Text("/sec")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.green.opacity(0.75))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.green.opacity(0.14), in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.green.opacity(0.35), lineWidth: 1))
    }

    // MARK: - Secondary chips

    private var shardsChip: some View {
        HStack(spacing: 4) {
            Image(systemName: "diamond.fill").font(.caption).foregroundStyle(.cyan)
            Text(Formatter.short(engine.state.cosmicShards))
                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                .foregroundStyle(.white)
                .monospacedDigit()
            Text("◈").font(.caption2).foregroundStyle(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.cyan.opacity(0.14), in: Capsule())
    }

    private var boostBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: "bolt.fill").font(.caption2).foregroundStyle(.orange)
            Text("2× BOOST").font(.caption2.bold()).foregroundStyle(.orange)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.orange.opacity(0.14), in: Capsule())
    }
}

/// A small dot that pulses once a second — a subtle "the game is running" signal.
/// Uses TimelineView so it re-renders on its own schedule without needing to
/// observe engine state.
private struct PulsingDot: View {
    let color: Color

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.5)) { ctx in
            let phase = Int(ctx.date.timeIntervalSince1970 * 2) % 2
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
                .shadow(color: color, radius: phase == 0 ? 6 : 2)
                .opacity(phase == 0 ? 1.0 : 0.55)
                .animation(.easeInOut(duration: 0.5), value: phase)
        }
    }
}
