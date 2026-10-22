import SwiftUI

/// The Cosmic tree — spend Cosmic Shards (◈) on permanent, level-able upgrades.
/// Shards are also a passive multiplier (+2% each while unspent), so every level
/// bought is a real invest-or-hoard tradeoff.
struct CosmicTreeView: View {
    @Environment(GameEngine.self) var engine
    @Environment(HapticsManager.self) var haptics

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 12) {
                    balanceHeader
                    ForEach(CosmicTree.skills) { skill in
                        skillRow(skill)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 24)
            }
        }
        .navigationTitle("Cosmic Tree")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.black, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }

    private var balanceHeader: some View {
        VStack(spacing: 6) {
            HStack {
                Image(systemName: "diamond.fill").foregroundStyle(.cyan)
                Text("\(Formatter.short(engine.state.cosmicShards)) ◈ Cosmic Shards")
                    .font(.headline).foregroundStyle(.white).monospacedDigit()
                Spacer()
                Text("Passive: \(Formatter.multiplier(engine.state.shardMultiplier))")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Text("Each un-spent Shard gives +2% earnings. Spending them here reduces that passive bonus.")
                .font(.caption2).foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .padding(.top, 8)
    }

    private func skillRow(_ skill: CosmicSkill) -> some View {
        let level = engine.cosmicSkillLevel(skill.id)
        let ranks = max(0, level - skill.maxLevel)
        let regularDone = level >= skill.maxLevel
        let maxed = regularDone && !skill.hasRanks
        let cost = engine.cosmicSkillCost(skill.id)
        let canAfford = (cost.map { $0 <= engine.state.cosmicShards }) ?? false
        // v3.3 — past max, production nodes keep going as Stellar ranks (gold).
        let tint: Color = regularDone && skill.hasRanks ? Self.stellar : .cyan

        return HStack(spacing: 14) {
            Image(systemName: skill.symbol)
                .font(.title2)
                .frame(width: 40, height: 40)
                .foregroundStyle(tint)
                .background(tint.opacity(0.18), in: RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(skill.name).font(.subheadline.bold()).foregroundStyle(.white)
                    Spacer()
                    Text(ranks > 0 ? "Lv \(skill.maxLevel) · ★\(ranks)" : "Lv \(min(level, skill.maxLevel))/\(skill.maxLevel)")
                        .font(.caption.bold())
                        .foregroundStyle(maxed ? .green : (ranks > 0 ? Self.stellar : .secondary))
                        .monospacedDigit()
                }
                Text(skill.detail).font(.caption).foregroundStyle(.secondary)
                if regularDone, let rank = skill.rankMultiplier {
                    Text("Stellar rank: ×\(String(format: "%.2f", rank)) per rank (4× the cost each time)")
                        .font(.caption2).foregroundStyle(Self.stellar)
                } else {
                    ProgressView(value: Double(min(level, skill.maxLevel)), total: Double(skill.maxLevel)).tint(.cyan)
                }
            }

            if maxed {
                Image(systemName: "checkmark.seal.fill").foregroundStyle(.green)
            } else {
                Button {
                    if engine.buyCosmicSkill(skill.id) { haptics.skillUnlock() } else { haptics.error() }
                } label: {
                    Text("\(Formatter.short(cost ?? 0)) ◈")
                        .font(.caption.bold())
                        .padding(.vertical, 6).padding(.horizontal, 10)
                        .background(canAfford ? tint : Color.gray.opacity(0.3),
                                    in: RoundedRectangle(cornerRadius: 8))
                        .foregroundStyle(.black)
                }
                .disabled(!canAfford)
            }
        }
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
    }

    private static let stellar = Color(red: 1.0, green: 0.80, blue: 0.32)
}
