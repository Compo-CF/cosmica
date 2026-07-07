import SwiftUI

/// Detail sheet for a single generator type. Shows current stats and — once the player
/// owns enough units — lets them commit the generator to a specialization for the run.
struct GeneratorDetailSheet: View {
    @Environment(GameEngine.self) var engine
    @Environment(HapticsManager.self) var haptics
    @Environment(\.dismiss) var dismiss

    let generatorId: String

    private var generator: Generator? {
        engine.state.generators.first { $0.id == generatorId }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                if let g = generator {
                    ScrollView {
                        VStack(spacing: 20) {
                            header(gen: g)
                            statBlock(gen: g)
                            specializationSection(gen: g)
                        }
                        .padding()
                        .padding(.bottom, 24)
                    }
                } else {
                    Text("Generator not found").foregroundStyle(.secondary)
                }
            }
            .navigationTitle(generator?.name ?? "Generator")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.black, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(.cyan)
                }
            }
        }
    }

    private func header(gen: Generator) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.purple.opacity(0.20))
                Image(systemName: gen.symbol)
                    .font(.system(size: 32))
                    .foregroundStyle(.purple)
            }
            .frame(width: 66, height: 66)

            VStack(alignment: .leading, spacing: 4) {
                Text("Tier \(gen.index + 1) generator")
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
                if let spec = gen.specializationDetail {
                    Label(spec.name, systemImage: spec.symbol)
                        .font(.caption.bold())
                        .foregroundStyle(.orange)
                }
            }
            Spacer()
        }
    }

    private func statBlock(gen: Generator) -> some View {
        VStack(spacing: 10) {
            statRow("Owned",           value: "\(gen.count)")
            statRow("Per-unit rate",   value: "\(Formatter.short(gen.unitRate(with: engine.state.upgrades)))/s")
            statRow("Total rate",      value: "\(Formatter.short(gen.ratePerSecond(with: engine.state.upgrades)))/s")
            statRow("Next cost",       value: "\(Formatter.short(gen.nextCost)) ✦")
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private func statRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            Text(value).foregroundStyle(.white).monospacedDigit()
        }
        .font(.subheadline)
    }

    @ViewBuilder
    private func specializationSection(gen: Generator) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "wand.and.stars.inverse").foregroundStyle(.orange)
                Text("Specialization").font(.headline).foregroundStyle(.white)
                Spacer()
            }

            if let current = gen.specializationDetail {
                specCard(spec: current, chosen: true, canPick: false)
                Text("Locked in until the next Big Bang.")
                    .font(.caption).foregroundStyle(.secondary)
            } else if gen.count < GeneratorSpecCatalog.ownershipRequirement {
                lockedCard(needed: GeneratorSpecCatalog.ownershipRequirement - gen.count)
            } else {
                Text("Pick one archetype for \(gen.name) — locked until you Big Bang.")
                    .font(.caption).foregroundStyle(.secondary)
                ForEach(GeneratorSpecCatalog.specs) { spec in
                    specCard(spec: spec, chosen: false, canPick: true)
                }
            }
        }
    }

    private func lockedCard(needed: Int) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "lock.fill").foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text("Specialization locked").font(.subheadline.bold()).foregroundStyle(.white)
                Text("Build \(needed) more to unlock a permanent archetype for this run.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding()
        .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 12))
    }

    private func specCard(spec: GeneratorSpecialization, chosen: Bool, canPick: Bool) -> some View {
        HStack(spacing: 14) {
            Image(systemName: spec.symbol)
                .font(.title2)
                .frame(width: 44, height: 44)
                .foregroundStyle(chosen ? .orange : .white)
                .background(
                    (chosen ? Color.orange.opacity(0.18) : Color.white.opacity(0.08)),
                    in: RoundedRectangle(cornerRadius: 10)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(spec.name).font(.subheadline.bold()).foregroundStyle(.white)
                Text(spec.detail).font(.caption).foregroundStyle(.secondary)
                Text(spec.flavor).font(.caption2).italic().foregroundStyle(.white.opacity(0.5))
            }

            Spacer()

            if chosen {
                Image(systemName: "checkmark.seal.fill").foregroundStyle(.orange)
            } else if canPick {
                Button {
                    if engine.specialize(generatorId: generatorId, specId: spec.id) {
                        haptics.specialize()
                    } else {
                        haptics.error()
                    }
                } label: {
                    Text("Commit")
                        .font(.caption.bold())
                        .padding(.vertical, 7).padding(.horizontal, 12)
                        .background(.orange, in: RoundedRectangle(cornerRadius: 8))
                        .foregroundStyle(.black)
                }
            }
        }
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}
