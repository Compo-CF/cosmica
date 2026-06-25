import Foundation

struct Upgrade: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let cost: Double
    let multiplier: Double
    /// Generator this upgrade buffs. Empty string means global (applies to all generators).
    let targetGeneratorId: String
    /// Owned count of the target generator required before this upgrade is purchasable.
    let unlockOwnedCount: Int
    var purchased: Bool = false

    var isGlobal: Bool { targetGeneratorId.isEmpty }

    /// Whether the upgrade is visible/affordable in the shop given current state.
    func isUnlocked(generators: [Generator]) -> Bool {
        if isGlobal { return true }
        guard let g = generators.first(where: { $0.id == targetGeneratorId }) else { return false }
        return g.count >= unlockOwnedCount
    }
}
