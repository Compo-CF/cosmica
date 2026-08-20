import SwiftUI

/// Buy-mode selection shared across the Observatory's generator rows. Persisted via
/// @AppStorage("generatorBuyMode") so the choice sticks across launches, and every
/// GeneratorRow reads the same value — no more hunting for the long-press context menu.
enum GeneratorBuyMode: String, CaseIterable, Identifiable {
    case one   = "1"
    case five  = "5"
    case ten   = "10"
    case max   = "Max"

    var id: String { rawValue }

    /// Concrete amount, or nil for "buy the max affordable".
    var amount: Int? {
        switch self {
        case .one:  return 1
        case .five: return 5
        case .ten:  return 10
        case .max:  return nil
        }
    }
}

struct GeneratorRow: View {
    @Environment(GameEngine.self) var engine
    @Environment(HapticsManager.self) var haptics
    @AppStorage("generatorBuyMode") private var buyMode: GeneratorBuyMode = .one

    let generator: Generator
    @State private var showDetail: Bool = false

    /// Engine's authoritative copy — carries the current count and any specialization.
    private var liveGenerator: Generator? {
        engine.state.generators.first { $0.id == generator.id }
    }

    private var owned: Int { liveGenerator?.count ?? 0 }

    private var unlocked: Bool {
        // Unlock cascades — the very first is always unlocked, others require the previous one owned.
        guard generator.index > 0 else { return true }
        let prev = engine.state.generators.first { $0.index == generator.index - 1 }
        return (prev?.count ?? 0) >= 1
    }

    /// Actual number of units this tap will attempt to buy given the current mode and
    /// the player's Stardust. Max resolves to whatever they can afford right now (at
    /// least 1 so the button label always has a meaningful count).
    private var purchaseAmount: Int {
        if let fixed = buyMode.amount { return fixed }
        let n = generator.maxAffordable(budget: engine.state.stardust)
        return max(n, 1)
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
        Group {
            if !unlocked { lockedView } else { unlockedView }
        }
        .sheet(isPresented: $showDetail) {
            GeneratorDetailSheet(generatorId: generator.id)
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
                    if let spec = liveGenerator?.specializationDetail {
                        Image(systemName: spec.symbol)
                            .font(.caption2.bold())
                            .foregroundStyle(.orange)
                    }
                    Spacer()
                    Button { showDetail = true } label: {
                        Image(systemName: "info.circle")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    Text("\(owned)")
                        .font(.subheadline.bold())
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                Text("\(Formatter.short((liveGenerator ?? generator).unitRate(with: engine.state.upgrades)))/s each")
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
                .frame(minWidth: 74)
                .padding(.vertical, 8)
                .padding(.horizontal, 10)
                .background(canAfford ? Color.purple : Color.gray.opacity(0.3), in: RoundedRectangle(cornerRadius: 10))
                .foregroundStyle(canAfford ? .white : .secondary)
            }
            .disabled(!canAfford)
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

/// Segmented pill selector for the global buy mode. Placed above the generator list on
/// the Observatory; every GeneratorRow reads the same @AppStorage-backed value.
struct BuyModePicker: View {
    @AppStorage("generatorBuyMode") private var buyMode: GeneratorBuyMode = .one
    @Environment(HapticsManager.self) var haptics

    var body: some View {
        HStack(spacing: 6) {
            ForEach(GeneratorBuyMode.allCases) { mode in
                Button {
                    if buyMode != mode { haptics.purchase() }
                    buyMode = mode
                } label: {
                    Text(mode.rawValue)
                        .font(.caption.bold())
                        .monospacedDigit()
                        .frame(maxWidth: .infinity, minHeight: 30)
                        .background(
                            buyMode == mode ? Color.purple : Color.white.opacity(0.06),
                            in: RoundedRectangle(cornerRadius: 8)
                        )
                        .foregroundStyle(buyMode == mode ? .white : .secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(6)
        .background(Color.black.opacity(0.35), in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.08), lineWidth: 1))
        .padding(.horizontal)
    }
}
