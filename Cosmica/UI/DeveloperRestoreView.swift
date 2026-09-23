import SwiftUI

/// Developer-only tool for rebuilding a lost save (v3.0.2). Only reachable from
/// Settings when `DevTools.isAvailable()` — never visible in App Store installs.
///
/// Fields prefill from the current save. Apply writes the save locally, then
/// force-pushes to iCloud. The save it replaces is checkpointed first, so an
/// Apply is undoable via Settings → Restore previous save.
struct DeveloperRestoreView: View {
    @Environment(GameEngine.self) private var engine

    // Number fields are text so they accept scientific notation (1.5e40).
    @State private var cosmosCount = ""
    @State private var realityFragments = ""
    @State private var absoluteAscended = false
    @State private var prestigeCount = ""
    @State private var cosmicShards = ""
    @State private var lifetimeCosmicShards = ""
    @State private var stardust = ""
    @State private var lifetimeStardust = ""
    @State private var generatorsEach = ""
    @State private var achievementsUnlocked = 0
    @State private var wonders: Set<String> = []
    @State private var skillLevels: [String: Int] = [:]

    @State private var loaded = false
    @State private var confirmApply = false
    @State private var status: String?

    var body: some View {
        Form {
            Section {
                Text("Rebuilds a lost save. Number fields accept scientific notation, e.g. 1.5e40. The save being replaced is kept as the iCloud backup, so this is undoable.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("True Cosmos (meta-prestige)") {
                numberField("True Cosmos count", $cosmosCount)
                numberField("Reality Fragments", $realityFragments)
                Toggle("Absolute Ascended", isOn: $absoluteAscended)
            }

            Section("Current cosmos") {
                numberField("Big Bangs (prestige count)", $prestigeCount)
                numberField("Cosmic Shards (unspent)", $cosmicShards)
                numberField("Lifetime Cosmic Shards", $lifetimeCosmicShards)
                numberField("Stardust (balance)", $stardust)
                numberField("Lifetime Stardust (this run)", $lifetimeStardust)
                numberField("Units of every generator", $generatorsEach)
            }

            Section("Achievements") {
                Stepper("Unlocked: \(achievementsUnlocked) / \(AchievementCatalog.all.count)",
                        value: $achievementsUnlocked, in: 0...AchievementCatalog.all.count)
            }

            Section("Cosmic Wonders") {
                ForEach(WondersCatalog.all) { wonder in
                    Toggle(wonder.title, isOn: Binding(
                        get: { wonders.contains(wonder.id) },
                        set: { on in if on { wonders.insert(wonder.id) } else { wonders.remove(wonder.id) } }
                    ))
                }
            }

            Section("Cosmic Tree") {
                ForEach(CosmicTree.skills) { skill in
                    Stepper("\(skill.name): \(skillLevels[skill.id] ?? 0)/\(skill.maxLevel)",
                            value: Binding(
                                get: { skillLevels[skill.id] ?? 0 },
                                set: { skillLevels[skill.id] = $0 }
                            ),
                            in: 0...skill.maxLevel)
                }
                Button("Max every node") {
                    for skill in CosmicTree.skills { skillLevels[skill.id] = skill.maxLevel }
                }
            }

            Section {
                Button("Apply to this save", role: .destructive) { confirmApply = true }
                if let status {
                    Text(status).font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Developer Restore")
        .onAppear { if !loaded { prefill(); loaded = true } }
        .confirmationDialog("Overwrite the current save?", isPresented: $confirmApply, titleVisibility: .visible) {
            Button("Apply", role: .destructive) { apply() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The current save becomes the iCloud backup, restorable from Settings.")
        }
    }

    private func numberField(_ label: String, _ text: Binding<String>) -> some View {
        HStack {
            Text(label)
            Spacer()
            TextField("0", text: text)
                .keyboardType(.numbersAndPunctuation)
                .multilineTextAlignment(.trailing)
                .monospacedDigit()
                .frame(maxWidth: 160)
        }
    }

    private func prefill() {
        let s = engine.state
        cosmosCount = String(s.cosmosCount)
        realityFragments = String(s.realityFragments)
        absoluteAscended = s.hasAbsoluteAscended
        prestigeCount = String(s.prestigeCount)
        cosmicShards = String(s.cosmicShards)
        lifetimeCosmicShards = String(s.lifetimeCosmicShards)
        stardust = String(s.stardust)
        lifetimeStardust = String(s.lifetimeStardust)
        generatorsEach = String(s.generators.map(\.count).max() ?? 0)
        achievementsUnlocked = s.unlockedAchievementIds.count
        wonders = s.builtWonderIds
        skillLevels = s.cosmicSkillLevels
    }

    private func apply() {
        var s = engine.state
        if let v = Int(cosmosCount) { s.cosmosCount = max(0, v) }
        if let v = Double(realityFragments), v.isFinite {
            s.realityFragments = max(0, v)
            s.lifetimeRealityFragments = max(s.lifetimeRealityFragments, s.realityFragments)
        }
        if absoluteAscended {
            s.absoluteAscendedAt = s.absoluteAscendedAt ?? Date()
            s.absoluteCelebrationShown = true   // skip replaying the one-time sheet
        } else {
            s.absoluteAscendedAt = nil
        }
        if let v = Int(prestigeCount) { s.prestigeCount = max(0, v) }
        if let v = Double(cosmicShards), v.isFinite { s.cosmicShards = max(0, v) }
        if let v = Double(lifetimeCosmicShards), v.isFinite { s.lifetimeCosmicShards = max(0, v) }
        s.lifetimeCosmicShards = max(s.lifetimeCosmicShards, s.cosmicShards)
        if let v = Double(stardust), v.isFinite { s.stardust = max(0, v) }
        if let v = Double(lifetimeStardust), v.isFinite { s.lifetimeStardust = max(0, v) }
        s.lifetimeStardust = max(s.lifetimeStardust, s.stardust)
        if let n = Int(generatorsEach), n > 0 {
            for i in s.generators.indices { s.generators[i].count = n }
        }
        s.unlockedAchievementIds = Set(AchievementCatalog.all.prefix(achievementsUnlocked).map(\.id))
        s.builtWonderIds = wonders
        s.cosmicSkillLevels = skillLevels.filter { $0.value > 0 }
        s.lastSeen = Date()   // no surprise offline windfall on next launch

        engine.state = s
        engine.save()
        status = "Saved on this phone. Uploading to iCloud…"
        Task {
            do {
                _ = try await CloudSync.shared.push(state: s, force: true)
                status = "Restored and uploaded to iCloud."
            } catch {
                status = "Saved on this phone. iCloud upload failed — it retries when you leave the app."
            }
        }
    }
}
