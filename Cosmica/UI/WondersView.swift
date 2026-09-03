import SwiftUI

/// Cosmic Wonders build screen. One row per wonder in `WondersCatalog.all`.
/// Built wonders persist across every reset — the row shows the effect
/// permanently; unbuilt rows show gating (Cosmos count) and price (Cosmic Shards).
struct WondersView: View {
    @Environment(GameEngine.self) private var engine
    @Environment(HapticsManager.self) private var haptics

    var body: some View {
        ZStack {
            background
            ScrollView {
                VStack(spacing: 14) {
                    headerCard
                    ForEach(WondersCatalog.all) { w in
                        WonderRow(wonder: w) {
                            let ok = engine.buildWonder(id: w.id)
                            if ok { haptics.skillUnlock() }
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.top, 6)
                .padding(.bottom, 24)
            }
        }
        .navigationTitle("Cosmic Wonders")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.black, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }

    private var background: some View {
        ZStack {
            Color.black
            RadialGradient(
                colors: [Color.pink.opacity(0.20), .clear],
                center: .top, startRadius: 5, endRadius: 380
            )
        }
        .ignoresSafeArea()
    }

    private var headerCard: some View {
        let built = engine.state.builtWonderIds.count
        let total = WondersCatalog.all.count
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "building.columns.fill")
                    .font(.title2)
                    .foregroundStyle(.pink)
                    .frame(width: 40)
                VStack(alignment: .leading) {
                    Text("\(built) of \(total) built")
                        .font(.headline).foregroundStyle(.white)
                    Text("Permanent — Wonders survive Big Bang and True Cosmos.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
            }
            ProgressView(value: total > 0 ? Double(built) / Double(total) : 0)
                .tint(.pink)
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal)
    }
}

private struct WonderRow: View {
    @Environment(GameEngine.self) private var engine
    let wonder: CosmicWonder
    let onBuild: () -> Void

    var body: some View {
        let built = engine.state.builtWonderIds.contains(wonder.id)
        let cosmosOk = engine.state.cosmosCount >= wonder.cosmosRequired
        let shardsOk = engine.state.cosmicShards >= wonder.shardCost
        let color = Color(hex: wonder.colorHex)

        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(color.opacity(built ? 0.9 : 0.35)).frame(width: 46, height: 46)
                    Image(systemName: built ? wonder.symbol : "lock.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(built ? .white : .secondary)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(wonder.title).font(.headline).foregroundStyle(.white)
                    Text(wonder.effect).font(.caption).foregroundStyle(color)
                }
                Spacer()
                if built {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.title3).foregroundStyle(.green)
                }
            }

            Text(wonder.flavor)
                .font(.caption2)
                .italic()
                .foregroundStyle(.secondary)

            if !built {
                HStack(spacing: 8) {
                    reqPill(icon: "infinity.circle.fill",
                            text: "\(engine.state.cosmosCount) / \(wonder.cosmosRequired) Cosmoi",
                            ok: cosmosOk)
                    reqPill(icon: "diamond.fill",
                            text: "\(Formatter.short(wonder.shardCost)) ◈",
                            ok: shardsOk)
                    Spacer()
                }
                Button(action: onBuild) {
                    Text(cosmosOk && shardsOk ? "Build" : "Locked")
                        .font(.subheadline.bold())
                        .frame(maxWidth: .infinity, minHeight: 40)
                        .background(cosmosOk && shardsOk ? color : Color.gray.opacity(0.25),
                                    in: RoundedRectangle(cornerRadius: 10))
                        .foregroundStyle(cosmosOk && shardsOk ? .white : .secondary)
                }
                .disabled(!(cosmosOk && shardsOk))
            }
        }
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
    }

    private func reqPill(icon: String, text: String, ok: Bool) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon).font(.caption2)
            Text(text).font(.caption2).monospacedDigit()
        }
        .padding(.horizontal, 8).padding(.vertical, 4)
        .background((ok ? Color.green : Color.red).opacity(0.18), in: Capsule())
        .foregroundStyle(ok ? .green : .red)
    }
}

// Local Color(hex:) — keeps WondersView self-contained. If a project-wide helper
// gets added later, remove this and pick up the shared one.
private extension Color {
    init(hex: String) {
        let h = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var v: UInt64 = 0
        Scanner(string: h).scanHexInt64(&v)
        let r = Double((v >> 16) & 0xFF) / 255.0
        let g = Double((v >>  8) & 0xFF) / 255.0
        let b = Double( v        & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b)
    }
}
