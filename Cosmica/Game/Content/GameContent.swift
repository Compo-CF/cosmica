import Foundation

/// Static seed data for the game world.
///
/// Generators ladder up by ~15× in unit production and ~12× in initial cost per tier.
/// Cost growth (1.07–1.17) tightens slightly per tier so later generators stay relevant
/// without making early ones obsolete.
enum GameContent {
    static let defaultGenerators: [Generator] = [
        Generator(id: "g01", name: "Backyard Telescope",     index: 0,  baseCost: 10,                  baseRate: 0.1,         costGrowth: 1.07, symbol: "binoculars"),
        Generator(id: "g02", name: "Observatory",            index: 1,  baseCost: 100,                 baseRate: 1,           costGrowth: 1.08, symbol: "building.2"),
        Generator(id: "g03", name: "Radio Telescope Array",  index: 2,  baseCost: 1_200,               baseRate: 8,           costGrowth: 1.09, symbol: "antenna.radiowaves.left.and.right"),
        Generator(id: "g04", name: "Orbital Imager",         index: 3,  baseCost: 15_000,              baseRate: 47,          costGrowth: 1.10, symbol: "scope"),
        Generator(id: "g05", name: "Deep Field Surveyor",    index: 4,  baseCost: 200_000,             baseRate: 260,         costGrowth: 1.11, symbol: "moon.stars"),
        Generator(id: "g06", name: "Solar Probe",            index: 5,  baseCost: 3_000_000,           baseRate: 1_400,       costGrowth: 1.12, symbol: "sun.max"),
        Generator(id: "g07", name: "Interstellar Drone",     index: 6,  baseCost: 50_000_000,          baseRate: 7_800,       costGrowth: 1.13, symbol: "airplane.departure"),
        Generator(id: "g08", name: "Wormhole Sensor",        index: 7,  baseCost: 800_000_000,         baseRate: 44_000,      costGrowth: 1.14, symbol: "tornado"),
        Generator(id: "g09", name: "Dyson Swarm Lattice",    index: 8,  baseCost: 12_000_000_000,      baseRate: 260_000,     costGrowth: 1.15, symbol: "circle.hexagongrid"),
        Generator(id: "g10", name: "Galactic Survey Net",    index: 9,  baseCost: 200_000_000_000,     baseRate: 1_600_000,   costGrowth: 1.15, symbol: "globe.americas.fill"),
        Generator(id: "g11", name: "Multiverse Receiver",    index: 10, baseCost: 3_000_000_000_000,   baseRate: 10_000_000,  costGrowth: 1.16, symbol: "circle.dotted.and.circle"),
        Generator(id: "g12", name: "Demiurge Engine",        index: 11, baseCost: 50_000_000_000_000,  baseRate: 65_000_000,  costGrowth: 1.17, symbol: "sparkles"),
        // v1.3 — post-Demiurge frontier. Same ~15× per-tier scaling.
        Generator(id: "g13", name: "Chrono-Engine",          index: 12, baseCost: 800_000_000_000_000,     baseRate: 500_000_000,       costGrowth: 1.17, symbol: "clock.arrow.circlepath"),
        Generator(id: "g14", name: "Entropic Field",         index: 13, baseCost: 15_000_000_000_000_000,  baseRate: 4_000_000_000,     costGrowth: 1.18, symbol: "waveform.path"),
        Generator(id: "g15", name: "Anthropic Prism",        index: 14, baseCost: 300_000_000_000_000_000, baseRate: 30_000_000_000,    costGrowth: 1.18, symbol: "cube.transparent.fill"),
        Generator(id: "g16", name: "Primordial Engine",      index: 15, baseCost: 6e18,                    baseRate: 250_000_000_000,   costGrowth: 1.19, symbol: "flame.circle.fill"),
    ]

    /// Three escalating per-generator upgrades, unlocked by ownership milestones.
    /// Cost = baseCost × multiplierFactor so upgrades stay proportional across the curve.
    static let defaultUpgrades: [Upgrade] = {
        let perGenTiers: [(suffix: String, label: String, multi: Double, costFactor: Double, unlockAt: Int)] = [
            ("u1", "+2× Output",  2.0,   25.0,    10),
            ("u2", "+2× Output",  2.0,   200.0,   25),
            ("u3", "+3× Output",  3.0,   5_000.0, 50),
        ]
        var ups: [Upgrade] = []
        for g in defaultGenerators {
            for tier in perGenTiers {
                ups.append(Upgrade(
                    id: "\(g.id)-\(tier.suffix)",
                    name: "\(g.name) \(tier.label)",
                    cost: g.baseCost * tier.costFactor,
                    multiplier: tier.multi,
                    targetGeneratorId: g.id,
                    unlockOwnedCount: tier.unlockAt
                ))
            }
        }
        // Two global multipliers unlock late-game depth.
        ups.append(Upgrade(
            id: "global-u1",
            name: "Cosmic Background Calibration",
            cost: 1e9,
            multiplier: 1.5,
            targetGeneratorId: "",
            unlockOwnedCount: 0
        ))
        ups.append(Upgrade(
            id: "global-u2",
            name: "Quantum Entanglement Network",
            cost: 1e15,
            multiplier: 2.0,
            targetGeneratorId: "",
            unlockOwnedCount: 0
        ))
        return ups
    }()
}
