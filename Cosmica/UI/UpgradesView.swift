import SwiftUI

struct UpgradesView: View {
    @Environment(GameEngine.self) var engine
    @Environment(HapticsManager.self) var haptics

    private var available: [Upgrade] {
        engine.state.upgrades
            .filter { !$0.purchased && $0.isUnlocked(generators: engine.state.generators) }
            .sorted { $0.cost < $1.cost }
    }

    private var purchased: [Upgrade] {
        engine.state.upgrades.filter { $0.purchased }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        CurrencyBar()
                            .background(.clear)

                        section(title: "Available", items: available, locked: false)
                        section(title: "Purchased", items: purchased, locked: true)

                        if available.isEmpty && purchased.isEmpty {
                            Text("Buy more generators to unlock upgrades.")
                                .foregroundStyle(.secondary)
                                .padding()
                        }
                    }
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle("Upgrades")
            .toolbarBackground(Color.black, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }

    @ViewBuilder
    private func section(title: String, items: [Upgrade], locked: Bool) -> some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .padding(.horizontal)
                ForEach(items) { up in
                    upgradeRow(up, locked: locked)
                }
            }
        }
    }

    private func upgradeRow(_ up: Upgrade, locked: Bool) -> some View {
        HStack {
            Image(systemName: up.isGlobal ? "globe" : "wand.and.stars")
                .foregroundStyle(.purple)
                .frame(width: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(up.name).font(.subheadline.bold()).foregroundStyle(.white)
                Text(up.isGlobal ? "Global ×\(String(format: "%.1f", up.multiplier))"
                                 : "×\(String(format: "%.1f", up.multiplier))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if locked {
                Image(systemName: "checkmark.seal.fill").foregroundStyle(.green)
            } else {
                Button {
                    if engine.buyUpgrade(id: up.id) { haptics.upgrade() }
                } label: {
                    Text("\(Formatter.short(up.cost)) ✦")
                        .font(.caption.bold())
                        .padding(.vertical, 6)
                        .padding(.horizontal, 10)
                        .background(engine.state.stardust >= up.cost ? Color.purple : Color.gray.opacity(0.3),
                                    in: RoundedRectangle(cornerRadius: 8))
                        .foregroundStyle(.white)
                }
                .disabled(engine.state.stardust < up.cost)
            }
        }
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }
}
