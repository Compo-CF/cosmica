import SwiftUI

/// v4.0 — the fourth prestige layer. Opens the first time a run passes 1.8e308.
/// Collapsing the Omniverse trades the Multiverse (sparks, Void Wonders, fragments)
/// for Echoes; Echoes multiply everything and buy the Omniverse nodes. Functional
/// pass — the 4.0 visual overhaul (plan phase 4) restyles every layer together.
struct OmniverseView: View {
    @Environment(GameEngine.self) var engine
    @Environment(HapticsManager.self) var haptics

    @State private var showConfirm = false
    @State private var collapseAnim = false

    static let gold = Color(red: 1.00, green: 0.82, blue: 0.40)
    static let teal = Color(red: 0.35, green: 0.95, blue: 0.85)

    var body: some View {
        ZStack {
            LinearGradient(colors: [.black, Color(red: 0.10, green: 0.07, blue: 0.02), .black],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            ScrollView {
                VStack(spacing: 22) {
                    header.padding(.top, 12)
                    echoRewardCard
                    dilationCard
                    resetSummaryCard
                    if engine.canCollapseOmniverse {
                        collapseButton
                    }
                    nodesSection
                }
                .padding(.bottom, 32)
            }
        }
        .navigationTitle("Omniverse")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.black, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .confirmationDialog("Collapse the Omniverse?", isPresented: $showConfirm, titleVisibility: .visible) {
            Button("Collapse (\(Formatter.count(engine.availableEchoes)) Echoes)", role: .destructive) {
                triggerCollapse()
            }
        } message: {
            Text("Your Void Sparks, Void Wonders, Reality Fragments, Cosmic Shards, tree and run reset. Cosmic Wonders, Omniverse nodes and your purchases stay.")
        }
    }

    // MARK: Sections

    private var header: some View {
        VStack(spacing: 8) {
            Image(systemName: "circle.hexagonpath.fill")
                .font(.system(size: 64, weight: .light))
                .foregroundStyle(LinearGradient(colors: [Self.gold, Self.teal], startPoint: .topLeading, endPoint: .bottomTrailing))
                .scaleEffect(collapseAnim ? 1.6 : 1)
                .opacity(collapseAnim ? 0.2 : 1)
            Text("\(Formatter.count(engine.state.echoes)) Echoes")
                .font(.title2.bold()).foregroundStyle(.white).monospacedDigit()
            Text("\(Formatter.multiplier(engine.state.echoMultiplier)) everything you earn")
                .font(.subheadline).foregroundStyle(Self.gold)
        }
    }

    private var echoRewardCard: some View {
        let best = engine.state.omniverseBestSoFar
        return card {
            HStack {
                Text("If you collapse now").font(.subheadline).foregroundStyle(.secondary)
                Spacer()
                Text("+\(Formatter.count(engine.availableEchoes)) Echoes")
                    .font(.title3.bold()).foregroundStyle(Self.gold).monospacedDigit()
            }
            ProgressView(value: OmniverseCalculator.progressToNextEcho(bestRun: best)).tint(Self.gold)
            Text("Best run this Omniverse: \(Formatter.short(best)) ✦. Every 100 orders of magnitude past 1.8e308 is ×10 Echoes.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private var dilationCard: some View {
        let d = engine.state.dilationStrength
        return card {
            Text("Dilation").font(.headline).foregroundStyle(.white)
            Text("Past 1.8e308, each ×10 of production counts for \(Int((d * 100).rounded()))%. Thin the Veil raises it to \(Int(Dilation.maxStrength * 100))%.")
                .font(.subheadline).foregroundStyle(.secondary)
            ProgressView(value: (d - Dilation.baseStrength) / (Dilation.maxStrength - Dilation.baseStrength))
                .tint(Self.teal)
        }
    }

    private var resetSummaryCard: some View {
        card {
            Text("A collapse resets").font(.headline).foregroundStyle(.white)
            bullet("Void Sparks (Spark Memory keeps a share), Void Wonders, Reality Fragments")
            bullet("Cosmic Shards, the Cosmic Tree, generators and the current run")
            bullet("The Cosmos Goal ladder starts again from the first cosmos")
            Text("Kept").font(.headline).foregroundStyle(.white).padding(.top, 4)
            bullet("Echoes, Omniverse nodes, Cosmic Wonders, achievements, challenge stars, purchases")
        }
    }

    private var collapseButton: some View {
        Button { showConfirm = true } label: {
            Text("Collapse the Omniverse — claim \(Formatter.count(engine.availableEchoes)) Echoes")
                .font(.headline)
                .frame(maxWidth: .infinity, minHeight: 54)
                .background(LinearGradient(colors: [Self.gold, Self.teal], startPoint: .leading, endPoint: .trailing),
                            in: RoundedRectangle(cornerRadius: 14))
                .foregroundStyle(.black)
        }
        .padding(.horizontal)
    }

    private var nodesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Omniverse Nodes").font(.title3.bold()).foregroundStyle(.white).padding(.horizontal)
            ForEach(OmniverseTree.all) { node in
                OmniverseNodeRow(node: node) {
                    if engine.buyOmniverseNode(id: node.id) { haptics.skillUnlock() } else { haptics.error() }
                }
            }
        }
    }

    // MARK: Helpers

    private func card<C: View>(@ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 10) { content() }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
            .padding(.horizontal)
    }

    private func bullet(_ text: String) -> some View {
        Text("• " + text).font(.caption).foregroundStyle(.secondary)
    }

    private func triggerCollapse() {
        withAnimation { collapseAnim = true }
        haptics.bigBang()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
            _ = engine.omniverseCollapse()
            withAnimation { collapseAnim = false }
        }
    }
}

private struct OmniverseNodeRow: View {
    @Environment(GameEngine.self) private var engine
    let node: OmniverseNode
    let onBuy: () -> Void

    var body: some View {
        let level = engine.state.omniverseLevel(node.id)
        let cost = engine.omniverseNodeCost(node.id)
        let canBuy = cost.map { engine.state.echoes >= $0 } ?? false
        return HStack(spacing: 12) {
            ZStack {
                Circle().fill(OmniverseView.gold.opacity(level > 0 ? 0.9 : 0.3)).frame(width: 44, height: 44)
                Image(systemName: node.symbol).foregroundStyle(level > 0 ? .black : .secondary)
            }
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(node.title).font(.headline).foregroundStyle(.white)
                    if node.maxLevel != 1 && level > 0 {
                        Text("Lv \(level)\(node.maxLevel > 0 ? "/\(node.maxLevel)" : "")")
                            .font(.caption.bold()).foregroundStyle(OmniverseView.gold)
                    }
                }
                Text(node.detail).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if let cost {
                Button(action: onBuy) {
                    Text("\(Formatter.count(cost))")
                        .font(.caption.bold())
                        .padding(.vertical, 6).padding(.horizontal, 10)
                        .background(canBuy ? OmniverseView.gold : Color.gray.opacity(0.3), in: RoundedRectangle(cornerRadius: 8))
                        .foregroundStyle(.black)
                }
                .disabled(!canBuy)
                .accessibilityLabel("Buy \(node.title) for \(Formatter.count(cost)) Echoes")
            } else {
                Image(systemName: "checkmark.seal.fill").foregroundStyle(.green)
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal)
    }
}
