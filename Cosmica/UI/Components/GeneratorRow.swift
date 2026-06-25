import SwiftUI

struct GeneratorRow: View {
    @Environment(GameEngine.self) var engine
    @Environment(HapticsManager.self) var haptics

    let generator: Generator
    @State private var buyMode: BuyMode = .one

    enum BuyMode: String, CaseIterable, Identifiable {
        case one = "×1", ten = "×10", max = "Max"
        var id: String { rawValue }
    }

    private var owned: Int {
        engine.state.generators.first(where: { $0.id == generator.id })?.count ?? 0
    }

    private var unlocked: Bool {
        // Unlock cascades — the very first is always unlocked, others require the previous one owned.
        guard generator.index > 0 else { return true }
        let prev = engine.state.generators.first { $0.index == generator.index - 1 }
        return (prev?.count ?? 0) >= 1
    }

    private var purchaseAmount: Int {
        switch buyMode {
        case .one: return 1
        case .ten: return 10
        case .max:
            let n = generator.maxAffordable(budget: engine.state.stardust)
            return max(n, 1)
        }
    }

    private var totalCost: Double {
        if buyMode == .max {
            let n = generator.maxAffordable(budget: engine.state.stardust)
            return n > 0 ? generator.bulkCost(amount: n) : generator.nextCost
        }
        return generator.bulkCost(amount: purchaseAmount)
    }

    private var canAfford: Bool { engine.state.stardust >= totalCost }

    var body: some View {
        if !unlocked {
            lockedView
        } else {
            unlockedView
        }
    }

    private var unlockedView: some View {
        HStack(spacing: 14) {
            Image(systemName: generator.symbol)
                .font(.title)
                .frame(width: 50, height: 50)
                .background(Color.purple.opacity(0.2), in: RoundedRectangle(cornerRadius: 12))
                .foregroundStyle(.purple)

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(generator.name)
                        .font(.headline)
                        .foregroundStyle(.white)
                    Spacer()
                    Text("\(owned)")
                        .font(.subheadline.bold())
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                Text("\(Formatter.short(generator.unitRate(with: engine.state.upgrades)))/s each")
                    .font(.caption)
                    .foregroundStyle(.green)
                    .monospacedDigit()
            }

            Button {
                let n = purchaseAmount
                if engine.buy(generatorId: generator.id, amount: n) {
                    haptics.purchase()
                }
            } label: {
                VStack(spacing: 2) {
                    Text(buyMode == .max ? "Max" : "Buy \(purchaseAmount)")
                        .font(.caption.bold())
                    Text("\(Formatter.short(totalCost)) ✦")
                        .font(.caption2)
                        .monospacedDigit()
                }
                .frame(minWidth: 70)
                .padding(.vertical, 8)
                .padding(.horizontal, 10)
                .background(canAfford ? Color.purple : Color.gray.opacity(0.3), in: RoundedRectangle(cornerRadius: 10))
                .foregroundStyle(canAfford ? .white : .secondary)
            }
            .disabled(!canAfford)
            .contextMenu {
                ForEach(BuyMode.allCases) { mode in
                    Button(mode.rawValue) { buyMode = mode }
                }
            }
        }
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
    }

    private var lockedView: some View {
        HStack(spacing: 14) {
            Image(systemName: "lock.fill")
                .font(.title2)
                .frame(width: 50, height: 50)
                .foregroundStyle(.secondary)
            Text("Unlocks after buying the previous generator")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(12)
        .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 14))
    }
}
