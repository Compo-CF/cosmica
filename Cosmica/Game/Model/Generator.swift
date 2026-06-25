import Foundation

struct Generator: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let index: Int
    let baseCost: Double
    let baseRate: Double      // stardust per second per unit owned
    let costGrowth: Double    // geometric growth factor (~1.07–1.17)
    let symbol: String        // SF Symbol
    var count: Int = 0

    var nextCost: Double {
        CostCurve.cost(base: baseCost, growth: costGrowth, owned: count)
    }

    func bulkCost(amount: Int) -> Double {
        CostCurve.bulkCost(base: baseCost, growth: costGrowth, owned: count, buying: amount)
    }

    func maxAffordable(budget: Double) -> Int {
        CostCurve.maxAffordable(base: baseCost, growth: costGrowth, owned: count, budget: budget)
    }

    /// Per-unit rate after applying all owned upgrades that target this generator.
    func unitRate(with upgrades: [Upgrade]) -> Double {
        let mult = upgrades
            .filter { $0.purchased && $0.targetGeneratorId == id }
            .reduce(1.0) { $0 * $1.multiplier }
        return baseRate * mult
    }

    /// Total contribution per second from this generator.
    func ratePerSecond(with upgrades: [Upgrade]) -> Double {
        unitRate(with: upgrades) * Double(count)
    }
}
