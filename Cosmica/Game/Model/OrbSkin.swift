import SwiftUI

/// v3.2 — looks for the Observatory tap orb. The 3.1 golden orb (Supporter Pack)
/// becomes one skin of several; the rest are earned through play, so a
/// long-running save has something visible to show for its milestones.
///
/// Unlocks are derived from the save (and Supporter ownership) every time,
/// so nothing new is persisted except which skin the player picked.
enum OrbSkin: String, CaseIterable, Identifiable {
    // v3.4 — singularity: exclusive to the Ultimate Bundle / Deluxe Upgrade.
    case tier, golden, singularity, aurora, nebula, pulsar, void

    var id: String { rawValue }

    /// AppStorage key for the player's pick.
    static let storageKey = "cosmica.orbSkin"
    /// 3.1's golden-orb switch (default on). Read once to carry a supporter's
    /// existing choice into the picker.
    static let legacyGoldenKey = "cosmica.supporter.goldenOrb"

    var title: String {
        switch self {
        case .tier:   return "Tier color"
        case .golden: return "Golden"
        case .singularity: return "Singularity"
        case .aurora: return "Aurora"
        case .nebula: return "Nebula"
        case .pulsar: return "Pulsar"
        case .void:   return "Void"
        }
    }

    /// How to unlock it, shown while locked.
    var requirement: String {
        switch self {
        case .tier:   return "Changes as you climb the tiers"
        case .golden: return "Supporter Pack"
        case .singularity: return "Ultimate Bundle or Deluxe Upgrade"
        case .aurora: return "Reach Absolute"
        case .nebula: return "Complete a True Cosmos"
        case .pulsar: return "Earn 5 Challenge Stars"
        case .void:   return "Complete 10 True Cosmoi"
        }
    }

    /// Core colour of the orb (nil = follow the current tier).
    var core: Color? {
        switch self {
        case .tier:   return nil
        case .golden: return Color(red: 1.00, green: 0.80, blue: 0.32)
        case .singularity: return Color(red: 0.10, green: 0.05, blue: 0.20)
        case .aurora: return Color(red: 0.35, green: 1.00, blue: 0.75)
        case .nebula: return Color(red: 1.00, green: 0.45, blue: 0.85)
        case .pulsar: return Color(red: 0.40, green: 0.75, blue: 1.00)
        case .void:   return Color(red: 0.45, green: 0.20, blue: 0.95)
        }
    }

    /// Second colour for the sparkle gradient and glow.
    var accent: Color {
        switch self {
        case .tier:   return .white
        case .golden: return Color(red: 1.00, green: 0.80, blue: 0.32)
        // A dark core with a hot accretion-disc rim.
        case .singularity: return Color(red: 1.00, green: 0.55, blue: 0.20)
        case .aurora: return Color(red: 0.55, green: 0.80, blue: 1.00)
        case .nebula: return Color(red: 0.70, green: 0.45, blue: 1.00)
        case .pulsar: return .white
        case .void:   return Color(red: 0.85, green: 0.75, blue: 1.00)
        }
    }

    func isUnlocked(state: GameState, supporter: Bool, premium: Bool = false) -> Bool {
        switch self {
        case .tier:   return true
        case .golden: return supporter
        case .singularity: return premium
        case .aurora: return state.hasAbsoluteAscended
        case .nebula: return state.cosmosCount >= 1
        case .pulsar: return state.challengeStars >= 5
        case .void:   return state.cosmosCount >= 10
        }
    }

    /// The skin to draw. An empty pick means "never chosen in 3.2": supporters
    /// keep the golden orb they had in 3.1 unless they'd switched it off.
    /// A pick that isn't unlocked (e.g. a restored save) falls back to tier colour.
    static func resolve(picked: String, legacyGolden: Bool, state: GameState, supporter: Bool,
                        premium: Bool = false) -> OrbSkin {
        if picked.isEmpty {
            return supporter && legacyGolden ? .golden : .tier
        }
        guard let skin = OrbSkin(rawValue: picked),
              skin.isUnlocked(state: state, supporter: supporter, premium: premium) else {
            return .tier
        }
        return skin
    }
}
