import SwiftUI

struct CurrencyBar: View {
    @Environment(GameEngine.self) var engine

    var body: some View {
        let tier = engine.state.currentTier
        HStack(spacing: 14) {
            currencyChip(symbol: "sparkles", value: engine.state.stardust, suffix: "✦", color: tier.color)
                .accessibilityLabel("\(Formatter.short(engine.state.stardust)) Stardust")
            currencyChip(symbol: "diamond.fill", value: engine.state.cosmicShards, suffix: "◈", color: .cyan)
                .accessibilityLabel("\(Formatter.short(engine.state.cosmicShards)) Cosmic Shards")
            Spacer()
            rate
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
        .overlay(alignment: .bottom) {
            Rectangle().fill(tier.color.opacity(0.3)).frame(height: 1)
        }
    }

    private func currencyChip(symbol: String, value: Double, suffix: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: symbol).foregroundStyle(color)
            Text(Formatter.short(value))
                .font(.system(.body, design: .rounded).weight(.semibold))
                .foregroundStyle(.white)
                .monospacedDigit()
            Text(suffix).font(.caption).foregroundStyle(.secondary)
        }
    }

    private var rate: some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text("\(Formatter.short(engine.state.stardustPerSecond))/s")
                .font(.system(.caption, design: .rounded).weight(.semibold))
                .foregroundStyle(.green)
                .monospacedDigit()
            if engine.state.adBoostMultiplier > 1.0 {
                Text("2× boost")
                    .font(.caption2.bold())
                    .foregroundStyle(.orange)
            }
        }
    }
}
