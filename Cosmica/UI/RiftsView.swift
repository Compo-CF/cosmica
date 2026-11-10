import SwiftUI

/// v4.0 — Rifts: challenge runs with one rule each and a permanent reward per tier.
/// Functional pass; the visual overhaul (plan phase 4) restyles it with the Omniverse.
struct RiftsView: View {
    @Environment(GameEngine.self) var engine
    @Environment(HapticsManager.self) var haptics
    @State private var confirmId: String?

    var body: some View {
        ZStack {
            DSLayerBackground(layer: .omniverse)
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Each Rift starts a fresh run under one rule. Reach its goal in that run to complete the next tier and keep its reward forever. Goals follow your best run, so they stay a challenge.")
                        .font(.subheadline).foregroundStyle(.secondary)
                        .padding(.horizontal)
                    if let rift = engine.activeRift {
                        activeCard(rift)
                    }
                    ForEach(RiftCatalog.all) { rift in
                        RiftRow(rift: rift, onEnter: { confirmId = rift.id })
                    }
                }
                .padding(.vertical, 16)
            }
        }
        .navigationTitle("Rifts")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.black, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .confirmationDialog("Enter the Rift?", isPresented: Binding(get: { confirmId != nil }, set: { if !$0 { confirmId = nil } }),
                            titleVisibility: .visible) {
            Button("Enter (resets this run)") {
                if let id = confirmId, engine.enterRift(id) { haptics.bigBang() } else { haptics.error() }
                confirmId = nil
            }
        } message: {
            Text("Your current run's Stardust and generators reset, as with a Big Bang (no shards are paid). Shards, the tree and every layer above are kept.")
        }
        .alert("Rift complete", isPresented: Binding(get: { engine.completedRiftId != nil },
                                                     set: { if !$0 { engine.acknowledgeRiftCompletion() } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(engine.completedRiftId.flatMap(RiftCatalog.rift(id:)).map { "\($0.title): \($0.reward)" } ?? "")
        }
    }

    private func activeCard(_ rift: Rift) -> some View {
        let now = max(engine.state.lifetimeStardust, Big.one).log10Value
        let goal = engine.state.riftGoalLog
        return VStack(alignment: .leading, spacing: 10) {
            Label("In the \(rift.title) Rift", systemImage: rift.symbol)
                .font(.headline).foregroundStyle(OmniverseView.teal)
            Text(rift.rule).font(.subheadline).foregroundStyle(.white)
            ProgressView(value: goal > 0 ? min(1, now / goal) : 0).tint(OmniverseView.teal)
            Text("This run: \(Formatter.short(engine.state.lifetimeStardust)) ✦ of \(Formatter.short(Big.fromLog10(goal))) ✦")
                .font(.caption).foregroundStyle(.secondary).monospacedDigit()
            Button("Leave the Rift") { engine.leaveRift() }
                .font(.caption.bold()).foregroundStyle(.red)
        }
        .dsCard(.omniverse, highlighted: true)
    }
}

private struct RiftRow: View {
    @Environment(GameEngine.self) private var engine
    let rift: Rift
    let onEnter: () -> Void

    var body: some View {
        let tier = engine.state.riftTier(rift.id)
        let goal = engine.riftGoalLog(for: rift.id)
        let busy = engine.state.activeRiftId != nil
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: rift.symbol).font(.title3).foregroundStyle(OmniverseView.gold).frame(width: 32)
                Text(rift.title).font(.headline).foregroundStyle(.white)
                Spacer()
                HStack(spacing: 4) {
                    ForEach(0..<RiftCatalog.maxTier, id: \.self) { i in
                        Circle().fill(i < tier ? OmniverseView.gold : Color.gray.opacity(0.35)).frame(width: 9, height: 9)
                    }
                }
                .accessibilityLabel("\(tier) of \(RiftCatalog.maxTier) tiers complete")
            }
            Text("Rule: \(rift.rule)").font(.caption).foregroundStyle(.secondary)
            Text("Reward: \(rift.reward)").font(.caption).foregroundStyle(OmniverseView.gold)
            if let goal {
                HStack {
                    Text("Tier \(tier + 1) goal: \(Formatter.short(Big.fromLog10(goal))) ✦ in one run")
                        .font(.caption).foregroundStyle(.secondary).monospacedDigit()
                    Spacer()
                    if engine.state.activeRiftId != rift.id {
                        Button("Enter", action: onEnter)
                            .font(.caption.bold())
                            .padding(.vertical, 6).padding(.horizontal, 12)
                            .background(busy ? Color.gray.opacity(0.3) : OmniverseView.teal, in: RoundedRectangle(cornerRadius: 8))
                            .foregroundStyle(.black)
                            .disabled(busy)
                    }
                }
            } else {
                Label("All tiers complete", systemImage: "checkmark.seal.fill").font(.caption.bold()).foregroundStyle(.green)
            }
        }
        .dsCard(.omniverse)
    }
}
