import Foundation

/// A specialization applied to a single Generator type once the player owns enough
/// units of it. Each generator can carry at most one specialization at a time, and
/// the choice resets when the player triggers Big Bang — a fresh pick every run.
///
/// v3.3 — every option is a trade-off. Before, they were +75% / +50% / +30% with no
/// downside, so the only sensible pick was the biggest number (App Store review,
/// 20 Oct 2026: "What's the point of choosing anything but the +75%?"). Now each
/// one wins in a different situation:
///   Overcharged — your strongest generator, if you can afford it (×3, costs ×2)
///   Resonant    — a wide spread of generators (+10% to every other one)
///   Thrifty     — early in a run, when count matters (costs half)
///   Night Shift — idle players (×4, but only while you're away)
/// The ids of the first three are the pre-3.3 ones, so a save that's mid-run keeps
/// its picks (they just take on the new effects).
struct GeneratorSpecialization: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let detail: String
    let symbol: String
    let flavor: String
    /// Multiplier on this generator's output while the game is open.
    let onlineMultiplier: Double
    /// Multiplier on this generator's output while the player is away.
    let offlineMultiplier: Double
    /// Multiplier on this generator's purchase price.
    let costMultiplier: Double
    /// Bonus this generator gives every *other* generator (additive, stacks per Resonant).
    let resonance: Double
}

enum GeneratorSpecCatalog {
    /// A generator must be owned in at least this quantity before it can be specialized.
    static let ownershipRequirement: Int = 25

    static let specs: [GeneratorSpecialization] = [
        GeneratorSpecialization(
            id: "overcharged",
            name: "Overcharged",
            detail: "×3 output from this generator. Each one costs twice as much.",
            symbol: "flame.fill",
            flavor: "Runs the instrument past its rated tolerance — bright, hot and expensive.",
            onlineMultiplier: 3, offlineMultiplier: 3, costMultiplier: 2, resonance: 0
        ),
        GeneratorSpecialization(
            id: "attuned",
            name: "Resonant",
            detail: "+10% output to every other generator. No bonus to this one.",
            symbol: "waveform.path.ecg",
            flavor: "Tuned to the whole array, so everything around it sings a little louder.",
            onlineMultiplier: 1, offlineMultiplier: 1, costMultiplier: 1, resonance: 0.10
        ),
        GeneratorSpecialization(
            id: "steady",
            name: "Night Shift",
            detail: "×4 output from this generator while you're away. Normal while you play.",
            symbol: "moon.stars.fill",
            flavor: "Does its best work when nobody is watching.",
            onlineMultiplier: 1, offlineMultiplier: 4, costMultiplier: 1, resonance: 0
        ),
        GeneratorSpecialization(
            id: "thrifty",
            name: "Thrifty",
            detail: "This generator costs half as much. Output unchanged.",
            symbol: "tag.fill",
            flavor: "Built from spare parts. Nobody can tell the difference.",
            onlineMultiplier: 1, offlineMultiplier: 1, costMultiplier: 0.5, resonance: 0
        ),
    ]

    static func spec(id: String) -> GeneratorSpecialization? {
        specs.first { $0.id == id }
    }
}
