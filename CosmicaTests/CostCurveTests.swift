import XCTest
@testable import Cosmica

final class CostCurveTests: XCTestCase {

    func test_singleCost_growsGeometrically() {
        XCTAssertEqual(CostCurve.cost(base: 10, growth: 1.07, owned: 0), 10, accuracy: 1e-9)
        XCTAssertEqual(CostCurve.cost(base: 10, growth: 1.07, owned: 1), 10.7, accuracy: 1e-9)
        XCTAssertEqual(CostCurve.cost(base: 10, growth: 1.07, owned: 10), 19.6715, accuracy: 1e-3)
    }

    func test_bulkCost_zeroBuying_returnsZero() {
        XCTAssertEqual(CostCurve.bulkCost(base: 10, growth: 1.07, owned: 5, buying: 0), 0)
    }

    func test_bulkCost_one_equalsSingleCost() {
        XCTAssertEqual(
            CostCurve.bulkCost(base: 100, growth: 1.10, owned: 3, buying: 1),
            CostCurve.cost(base: 100, growth: 1.10, owned: 3),
            accuracy: 1e-9
        )
    }

    func test_bulkCost_summation_matchesIndividualCosts() {
        let base = 100.0, growth = 1.12, owned = 0
        let n = 10
        let bulk = CostCurve.bulkCost(base: base, growth: growth, owned: owned, buying: n)
        let manual = (0..<n).reduce(0.0) { acc, i in acc + CostCurve.cost(base: base, growth: growth, owned: owned + i) }
        XCTAssertEqual(bulk, manual, accuracy: bulk * 1e-9)
    }

    func test_bulkCost_growthOne_isLinear() {
        let bulk = CostCurve.bulkCost(base: 50, growth: 1.0, owned: 5, buying: 7)
        XCTAssertEqual(bulk, 50 * 7, accuracy: 1e-9)
    }

    func test_maxAffordable_zeroBudget_returnsZero() {
        XCTAssertEqual(CostCurve.maxAffordable(base: 10, growth: 1.07, owned: 0, budget: 0), 0)
    }

    func test_maxAffordable_budgetEqualsBulkCost_returnsN() {
        let base = 10.0, growth = 1.07, owned = 0
        let n = 25
        let budget = CostCurve.bulkCost(base: base, growth: growth, owned: owned, buying: n)
        let computed = CostCurve.maxAffordable(base: base, growth: growth, owned: owned, budget: budget)
        // Allow off-by-one from log/floor rounding.
        XCTAssertTrue([n - 1, n].contains(computed),
                      "Expected \(n - 1) or \(n), got \(computed)")
    }

    func test_maxAffordable_inverts_bulkCost() {
        let cases: [(base: Double, growth: Double, owned: Int, budget: Double)] = [
            (10, 1.07, 0, 1_000),
            (100, 1.10, 5, 1e6),
            (1e6, 1.15, 0, 1e9),
        ]
        for c in cases {
            let n = CostCurve.maxAffordable(base: c.base, growth: c.growth, owned: c.owned, budget: c.budget)
            let cost = CostCurve.bulkCost(base: c.base, growth: c.growth, owned: c.owned, buying: n)
            let nextCost = CostCurve.bulkCost(base: c.base, growth: c.growth, owned: c.owned, buying: n + 1)
            XCTAssertLessThanOrEqual(cost, c.budget, "n=\(n) cost \(cost) exceeded budget \(c.budget)")
            XCTAssertGreaterThan(nextCost, c.budget, "n+1=\(n + 1) cost \(nextCost) did not exceed budget \(c.budget)")
        }
    }
}
