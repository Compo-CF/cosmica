import Foundation
import SwiftUI

/// The permanent progression track — tier is derived from `lifetimeStardust` and gates a
/// baseline earnings multiplier that survives Big Bang. Original 7 tiers (Stargazer →
/// Demiurge) shipped in v1.0; v1.3 added five more past Demiurge for players who reached
/// the end of the original ladder.
enum Tier: Int, CaseIterable, Codable, Comparable {
    case stargazer = 0
    case astronomer
    case astrophysicist
    case cosmologist
    case galacticCartographer
    case architectOfTheVoid
    case demiurge
    // v1.3 — post-Demiurge frontier
    case cosmocrat
    case omniscient
    case primordial
    case transcendent
    case absolute

    var title: String {
        switch self {
        case .stargazer:             return "Stargazer"
        case .astronomer:            return "Astronomer"
        case .astrophysicist:        return "Astrophysicist"
        case .cosmologist:           return "Cosmologist"
        case .galacticCartographer:  return "Galactic Cartographer"
        case .architectOfTheVoid:    return "Architect of the Void"
        case .demiurge:              return "Demiurge"
        case .cosmocrat:             return "Cosmocrat"
        case .omniscient:            return "Omniscient"
        case .primordial:            return "Primordial"
        case .transcendent:          return "Transcendent"
        case .absolute:              return "Absolute"
        }
    }

    var threshold: Double {
        switch self {
        case .stargazer:             return 0
        case .astronomer:            return 1e5
        case .astrophysicist:        return 1e8
        case .cosmologist:           return 1e11
        case .galacticCartographer:  return 1e14
        case .architectOfTheVoid:    return 1e17
        case .demiurge:              return 1e20
        // v1.3 — each rung is ~1000× harder to reach than the last, matching the
        // original curve. Absolute jumps 10000× to keep it feeling meaningful.
        case .cosmocrat:             return 1e23
        case .omniscient:            return 1e26
        case .primordial:            return 1e29
        case .transcendent:          return 1e32
        case .absolute:              return 1e36
        }
    }

    var multiplier: Double {
        switch self {
        case .stargazer:             return 1.0
        case .astronomer:            return 1.25
        case .astrophysicist:        return 1.6
        case .cosmologist:           return 2.0
        case .galacticCartographer:  return 2.75
        case .architectOfTheVoid:    return 4.0
        case .demiurge:              return 6.0
        // v1.3 — steeper multiplier curve on the frontier so late-game runs
        // still feel like a step-change with each tier crossed.
        case .cosmocrat:             return 8.5
        case .omniscient:            return 12.0
        case .primordial:            return 18.0
        case .transcendent:          return 28.0
        case .absolute:              return 45.0
        }
    }

    /// SF Symbol that captures the tier vibe
    var symbol: String {
        switch self {
        case .stargazer:             return "binoculars"
        case .astronomer:            return "moon.stars"
        case .astrophysicist:        return "atom"
        case .cosmologist:           return "globe.europe.africa.fill"
        case .galacticCartographer:  return "map"
        case .architectOfTheVoid:    return "circle.dotted.and.circle"
        case .demiurge:              return "sparkles"
        case .cosmocrat:             return "crown.fill"
        case .omniscient:            return "eye.fill"
        case .primordial:            return "flame.fill"
        case .transcendent:          return "seal.fill"
        case .absolute:              return "infinity.circle.fill"
        }
    }

    /// Accent color (UI tint) per tier
    var color: Color {
        switch self {
        case .stargazer:             return Color(red: 0.45, green: 0.50, blue: 0.85)
        case .astronomer:            return Color(red: 0.65, green: 0.75, blue: 0.90)
        case .astrophysicist:        return Color(red: 0.95, green: 0.80, blue: 0.30)
        case .cosmologist:           return Color(red: 0.75, green: 0.40, blue: 0.90)
        case .galacticCartographer:  return Color(red: 0.20, green: 0.85, blue: 0.80)
        case .architectOfTheVoid:    return Color(red: 0.95, green: 0.75, blue: 0.20)
        case .demiurge:              return Color(red: 1.00, green: 0.85, blue: 0.55)
        // v1.3 frontier: gold → deep purple → fire → electric → iridescent.
        case .cosmocrat:             return Color(red: 1.00, green: 0.72, blue: 0.20)
        case .omniscient:            return Color(red: 0.55, green: 0.20, blue: 0.95)
        case .primordial:            return Color(red: 1.00, green: 0.35, blue: 0.18)
        case .transcendent:          return Color(red: 0.30, green: 0.90, blue: 1.00)
        case .absolute:              return Color(red: 1.00, green: 0.55, blue: 0.90)
        }
    }

    static func current(forLifetime stardust: Double) -> Tier {
        Self.allCases.last { stardust >= $0.threshold } ?? .stargazer
    }

    func next() -> Tier? {
        let n = self.rawValue + 1
        return Tier(rawValue: n)
    }

    static func < (lhs: Tier, rhs: Tier) -> Bool { lhs.rawValue < rhs.rawValue }
}
