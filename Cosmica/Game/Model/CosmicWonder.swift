import Foundation

/// A one-time permanent unlock the player commits to at extreme cost. Each Wonder is
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
    let shardCost: Double
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
    ]

    static func wonder(id: String) -> CosmicWonder? {
        all.first(where: { $0.id == id })
    }
}
