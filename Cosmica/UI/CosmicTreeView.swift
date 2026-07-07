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
                Text("Passive: ×\(String(format: "%.2f", engine.state.shardMultiplier))")
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
        let maxed = level >= skill.maxLevel
        let cost = engine.cosmicSkillCost(skill.id)
        let canAfford = (cost.map { Double($0) <= engine.state.cosmicShards }) ?? false

        return HStack(spacing: 14) {
            Image(systemName: skill.symbol)
                .font(.title2)
                .frame(width: 40, height: 40)
                .foregroundStyle(.cyan)
                .background(Color.cyan.opacity(0.18), in: RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(skill.name).font(.subheadline.bold()).foregroundStyle(.white)
                    Spacer()
                    Text("Lv \(level)/\(skill.maxLevel)")
                        .font(.caption.bold())
                        .foregroundStyle(maxed ? .green : .secondary)
                        .monospacedDigit()
                }
                Text(skill.detail).font(.caption).foregroundStyle(.secondary)
                ProgressView(value: Double(level), total: Double(skill.maxLevel)).tint(.cyan)
            }

            if maxed {
                Image(systemName: "checkmark.seal.fill").foregroundStyle(.green)
            } else {
                Button {
                    if engine.buyCosmicSkill(skill.id) { haptics.skillUnlock() } else { haptics.error() }
                } label: {
                    Text("\(cost ?? 0) ◈")
                        .font(.caption.bold())
                        .padding(.vertical, 6).padding(.horizontal, 10)
                        .background(canAfford ? Color.cyan : Color.gray.opacity(0.3),
                                    in: RoundedRectangle(cornerRadius: 8))
                        .foregroundStyle(.black)
                }
                .disabled(!canAfford)
            }
        }
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
    }
}
