import Foundation

/// A Stardust-producing generator (Backyard Telescope, Observatory, …).
/// Owned in stacks; per-unit output scales with upgrades and — once the player owns
/// enough of them (`GeneratorSpecCatalog.ownershipRequirement`) — an optional
/// per-run `specialization` that resets on Big Bang.
struct Generator: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let index: Int
    let baseCost: Double
    let baseRate: Double      // stardust per second per unit owned
    let costGrowth: Double    // geometric growth factor (~1.07–1.17)
    let symbol: String        // SF Symbol
    var count: Int = 0
    /// The id of the chosen `GeneratorSpecialization`, or nil if not yet specialized.
    /// Optional-with-default keeps existing v1.0.x saves Codable-compatible.
    var specialization: String? = nil

    /// v3.3 — Overcharged doubles the price, Thrifty halves it.
    var costMultiplier: Double { specializationDetail?.costMultiplier ?? 1 }

    var nextCost: Double {
        CostCurve.cost(base: baseCost, growth: costGrowth, owned: count) * costMultiplier
    }

    func bulkCost(amount: Int) -> Double {
        CostCurve.bulkCost(base: baseCost, growth: costGrowth, owned: count, buying: amount) * costMultiplier
    }

    func maxAffordable(budget: Double) -> Int {
        CostCurve.maxAffordable(base: baseCost, growth: costGrowth, owned: count, budget: budget / costMultiplier)
    }

    // MARK: - Specialization

    var specializationDetail: GeneratorSpecialization? {
        guard let id = specialization else { return nil }
        return GeneratorSpecCatalog.spec(id: id)
    }

    /// True when the player can commit this generator to a specialization right now.
    var isSpecializable: Bool {
        count >= GeneratorSpecCatalog.ownershipRequirement && specialization == nil
    }

    /// Multiplier on this generator's own output from its specialization (1.0 if
    /// none). `offline` picks the away-from-the-game value (Night Shift).
    func specializationMultiplier(offline: Bool = false) -> Double {
        guard let spec = specializationDetail else { return 1 }
        return offline ? spec.offlineMultiplier : spec.onlineMultiplier
    }

    /// Bonus this generator gives every other generator (Resonant).
    var resonance: Double { specializationDetail?.resonance ?? 0 }

    // MARK: - Rate

    /// Per-unit rate after applying purchased upgrades and any specialization.
    func unitRate(with upgrades: [Upgrade], offline: Bool = false) -> Double {
        let upgradeMult = upgrades
            .filter { $0.purchased && $0.targetGeneratorId == id }
            .reduce(1.0) { $0 * $1.multiplier }
        return baseRate * upgradeMult * specializationMultiplier(offline: offline)
    }

    /// Total contribution per second from this generator (all units).
    func ratePerSecond(with upgrades: [Upgrade], offline: Bool = false) -> Double {
        unitRate(with: upgrades, offline: offline) * Double(count)
    }
}
