import Foundation
import SwiftUI

enum Tier: Int, CaseIterable, Codable, Comparable {
    case stargazer = 0
    case astronomer
    case astrophysicist
    case cosmologist
    case galacticCartographer
    case architectOfTheVoid
    case demiurge

    var title: String {
        switch self {
        case .stargazer:             return "Stargazer"
        case .astronomer:            return "Astronomer"
        case .astrophysicist:        return "Astrophysicist"
        case .cosmologist:           return "Cosmologist"
        case .galacticCartographer:  return "Galactic Cartographer"
        case .architectOfTheVoid:    return "Architect of the Void"
        case .demiurge:              return "Demiurge"
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
