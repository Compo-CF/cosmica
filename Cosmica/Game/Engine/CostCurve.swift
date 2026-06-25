import Foundation

/// Pure functions for the geometric cost curve used by every generator.
/// Kept free of state so it's trivial to unit-test (`CosmicaTests/CostCurveTests.swift`).
enum CostCurve {
    /// Cost of the next single purchase given how many are already owned.
    /// cost(n) = base * growth^n
    static func cost(base: Double, growth: Double, owned: Int) -> Double {
        base * pow(growth, Double(owned))
    }

    /// Total cost to buy `buying` more units in one transaction.
    /// Sum of geometric series: first * (g^n - 1) / (g - 1)
    static func bulkCost(base: Double, growth: Double, owned: Int, buying: Int) -> Double {
        guard buying > 0 else { return 0 }
        let first = cost(base: base, growth: growth, owned: owned)
        if abs(growth - 1.0) < 1e-9 {
            return first * Double(buying)
        }
        return first * (pow(growth, Double(buying)) - 1.0) / (growth - 1.0)
    }

    /// Max additional units affordable with `budget`, given current owned count.
    /// Inverts the bulk-cost formula:
    ///   budget >= first * (g^n - 1) / (g - 1)
    ///   n <= log( budget * (g - 1) / first + 1 ) / log(g)
    static func maxAffordable(base: Double, growth: Double, owned: Int, budget: Double) -> Int {
        guard budget > 0, base > 0 else { return 0 }
        let first = cost(base: base, growth: growth, owned: owned)
        if budget < first { return 0 }
        if abs(growth - 1.0) < 1e-9 {
            return Int(budget / first)
        }
        let inner = budget * (growth - 1.0) / first + 1.0
        guard inner > 0 else { return 0 }
        let n = log(inner) / log(growth)
        guard n.isFinite else { return 0 }
        return Int(n)
    }
}
