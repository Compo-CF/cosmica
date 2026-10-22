import Foundation

/// A permanent unlock the player commits to at extreme cost (v3.3: and keeps leveling). Each Wonder is
/// gated on both a Cosmos count and a Cosmic-Shard price, and its effect folds into
/// existing systems (offline cap, event ✦ multiplier, Big-Bang yield, tap value,
/// Reality-Fragment yield) via `GameState` computed properties.
///
/// Wonders persist through **every** reset — Big Bang and True Cosmos both leave
/// `builtWonderIds` alone.
struct CosmicWonder: Identifiable, Codable, Hashable {
    let id: String
    let title: String
    let flavor: String
    let effect: String
    let symbol: String
    let colorHex: String        // stored as hex so Codable stays simple
    let cosmosRequired: Int
    /// Cost of level 1 (building it). v3.3: each further level costs 10× the last.
    let shardCost: Double
    /// v3.3 — highest level (0 = no limit). One-shot Wonders are 1.
    var maxLevel: Int = 0

    /// Each level costs this many times the previous one.
    static let levelCostGrowth: Double = 10

    func cost(toReachLevel level: Int) -> Double {
        shardCost * pow(Self.levelCostGrowth, Double(max(0, level - 1)))
    }

    /// What the Wonder does at `level` (level 0 describes level 1, for unbuilt rows).
    func effect(atLevel level: Int) -> String {
        let l = max(1, level)
        switch id {
        case "chronosphere":      return "+\(12 * l) hours to offline earnings cap"
        case "nexus_lattice":     return "×\(1 + 2 * l) Stardust while any Cosmic Event is active"
        case "voidkeeper":        return "+\(50 * l)% Cosmic Shards from every Big Bang"
        case "multiverse_engine": return "Manual taps are worth ×\(Formatter.count(pow(2, Double(l))))"
        case "absolute_aperture": return "+\(25 * l)% Reality Fragments per True Cosmos"
        case "stellar_forge":     return "All generators ×\(Formatter.count(pow(2, Double(l))))"
        default:                  return effect
        }
    }
}

enum WondersCatalog {
    /// Ordering here matches the on-screen order in `WondersView`.
    static let all: [CosmicWonder] = [
        CosmicWonder(
            id: "chronosphere",
            title: "Chronosphere",
            flavor: "A frozen bubble of stalled time drifting in orbit.",
            effect: "+12 hours to offline earnings cap",
            symbol: "hourglass.circle.fill",
            colorHex: "4CE6FF",
            cosmosRequired: 1,
            shardCost: 5_000
        ),
        CosmicWonder(
            id: "nexus_lattice",
            title: "Nexus Lattice",
            flavor: "A crystalline scaffolding that reroutes cosmic tides toward you.",
            effect: "×3 Stardust while any Cosmic Event is active",
            symbol: "hexagon.righthalf.filled",
            colorHex: "B45AF5",
            cosmosRequired: 2,
            shardCost: 20_000
        ),
        CosmicWonder(
            id: "voidkeeper",
            title: "The Voidkeeper",
            flavor: "A silent warden that catches shards before the reset consumes them.",
            effect: "+50% Cosmic Shards from every Big Bang",
            symbol: "seal.fill",
            colorHex: "FFA633",
            cosmosRequired: 4,
            shardCost: 100_000
        ),
        CosmicWonder(
            id: "multiverse_engine",
            title: "Multiverse Engine",
            flavor: "Every tap ripples across a thousand adjacent realities.",
            effect: "Manual taps are worth ×2",
            symbol: "cpu.fill",
            colorHex: "FFDA4C",
            cosmosRequired: 7,
            shardCost: 500_000
        ),
        CosmicWonder(
            id: "absolute_aperture",
            title: "Absolute Aperture",
            flavor: "An opening onto the outside of the ladder — light pouring in.",
            effect: "+25% Reality Fragments per True Cosmos",
            symbol: "circle.hexagongrid.circle.fill",
            colorHex: "FF8CE6",
            cosmosRequired: 10,
            shardCost: 2_500_000
        ),
        // v3.3 — late Wonders that change how the game plays, for players whose
        // shard balance had nothing left to buy.
        CosmicWonder(
            id: "time_lens",
            title: "Time Lens",
            flavor: "Hold it up to the dark and the hours you were gone come back whole.",
            effect: "Offline earnings at your full online rate, not half",
            symbol: "camera.aperture",
            colorHex: "7CF5C8",
            cosmosRequired: 12,
            shardCost: 25_000_000,
            maxLevel: 1
        ),
        CosmicWonder(
            id: "event_horizon",
            title: "Event Horizon",
            flavor: "Pinned to the edge of a black hole, where something is always happening.",
            effect: "A Cosmic Event is always running: no wait between them",
            symbol: "circle.circle.fill",
            colorHex: "FF6B6B",
            cosmosRequired: 15,
            shardCost: 100_000_000,
            maxLevel: 1
        ),
        CosmicWonder(
            id: "stellar_forge",
            title: "Stellar Forge",
            flavor: "A furnace the size of a galaxy, beating out new stars on an anvil of light.",
            effect: "All generators ×2",
            symbol: "hammer.circle.fill",
            colorHex: "FFC24C",
            cosmosRequired: 20,
            shardCost: 10_000_000_000
        ),
    ]

    static func wonder(id: String) -> CosmicWonder? {
        all.first(where: { $0.id == id })
    }
}
