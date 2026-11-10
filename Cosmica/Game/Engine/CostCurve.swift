import Foundation

/// Pure functions for the geometric cost curve used by every generator.
/// Kept free of state so it's trivial to unit-test (`CosmicaTests/CostCurveTests.swift`).
///
/// v4.0 — costs are `Big`, computed in log space, so a generator owned thousands
/// of times (1.15^5000 ≈ 1e303) prices correctly instead of overflowing.
enum CostCurve {
    /// Cost of the next single purchase given how many are already owned.
    /// cost(n) = base * growth^n
    static func cost(base: Double, growth: Double, owned: Int) -> Big {
        Big.power(growth, Double(owned)) * base
    }

    /// Total cost to buy `buying` more units in one transaction.
    /// Sum of geometric series: first * (g^n - 1) / (g - 1)
    static func bulkCost(base: Double, growth: Double, owned: Int, buying: Int) -> Big {
        guard buying > 0 else { return .zero }
        let first = cost(base: base, growth: growth, owned: owned)
        if abs(growth - 1.0) < 1e-9 {
            return first * Double(buying)
        }
        return first * ((Big.power(growth, Double(buying)) - 1) / (growth - 1.0))
    }

    /// Max additional units affordable with `budget`, given current owned count.
    /// Inverts the bulk-cost formula:
    ///   budget >= first * (g^n - 1) / (g - 1)
    ///   n <= log( budget * (g - 1) / first + 1 ) / log(g)
    static func maxAffordable(base: Double, growth: Double, owned: Int, budget: Big) -> Int {
        guard budget > 0, base > 0 else { return 0 }
        let first = cost(base: base, growth: growth, owned: owned)
        if budget < first { return 0 }
        if abs(growth - 1.0) < 1e-9 {
            return clampedCount((budget / first).double)
        }
        let inner = budget * (growth - 1.0) / first + 1
        return clampedCount(inner.log10Value / log10(growth))
    }

    /// Whole units, never more than a billion at once (an Int conversion of a
    /// huge Double would trap).
    private static func clampedCount(_ n: Double) -> Int {
        guard n.isFinite, n > 0 else { return 0 }
        return Int(min(n, 1e9))
    }
}
