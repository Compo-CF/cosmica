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

    var nextCost: Double {
        CostCurve.cost(base: baseCost, growth: costGrowth, owned: count)
    }

    func bulkCost(amount: Int) -> Double {
        CostCurve.bulkCost(base: baseCost, growth: costGrowth, owned: count, buying: amount)
    }

    func maxAffordable(budget: Double) -> Int {
        CostCurve.maxAffordable(base: baseCost, growth: costGrowth, owned: count, budget: budget)
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

    /// Multiplier applied to raw rate from the current specialization (1.0 if none).
    var specializationMultiplier: Double {
        1.0 + (specializationDetail?.rateBoost ?? 0)
    }

    // MARK: - Rate

    /// Per-unit rate after applying purchased upgrades and any specialization.
    func unitRate(with upgrades: [Upgrade]) -> Double {
        let upgradeMult = upgrades
            .filter { $0.purchased && $0.targetGeneratorId == id }
            .reduce(1.0) { $0 * $1.multiplier }
        return baseRate * upgradeMult * specializationMultiplier
    }

    /// Total contribution per second from this generator (all units).
    func ratePerSecond(with upgrades: [Upgrade]) -> Double {
        unitRate(with: upgrades) * Double(count)
    }
}
