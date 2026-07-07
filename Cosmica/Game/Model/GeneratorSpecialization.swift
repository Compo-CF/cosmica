import Foundation

/// A permanent specialization applied to a single Generator type once the player owns
/// enough units of it. Each generator can carry at most one specialization at a time,
/// and the choice resets when the player triggers Big Bang — forcing a fresh strategic
/// pick every run.
struct GeneratorSpecialization: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let detail: String
    let symbol: String
    let flavor: String
    /// Fractional per-unit rate bonus applied inside `Generator.unitRate`.
    let rateBoost: Double
}

enum GeneratorSpecCatalog {
    /// A generator must be owned in at least this quantity before it can be specialized.
    static let ownershipRequirement: Int = 25

    static let specs: [GeneratorSpecialization] = [
        GeneratorSpecialization(
            id: "overcharged",
            name: "Overcharged",
            detail: "+75% Stardust per second.",
            symbol: "flame.fill",
            flavor: "Runs the instrument past its rated tolerance — bright and hot.",
            rateBoost: 0.75
        ),
        GeneratorSpecialization(
            id: "attuned",
            name: "Attuned",
            detail: "+50% Stardust per second.",
            symbol: "waveform.path.ecg",
            flavor: "Locked to a sharper resonance — reliable and clean.",
            rateBoost: 0.50
        ),
        GeneratorSpecialization(
            id: "steady",
            name: "Steady",
            detail: "+30% Stardust per second. Unshakeable.",
            symbol: "shield.lefthalf.filled",
            flavor: "Modest gain, disciplined output. Never falters.",
            rateBoost: 0.30
        ),
    ]

    static func spec(id: String) -> GeneratorSpecialization? {
        specs.first { $0.id == id }
    }
}
