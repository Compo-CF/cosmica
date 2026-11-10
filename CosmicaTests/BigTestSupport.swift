import XCTest
@testable import Cosmica

// v4.0 — assertions that compare a `Big` with a Double (usually a literal), so the
// pre-4.0 tests read the same: `XCTAssertEqual(state.cosmicShards, 35)`.
// `Big` is deliberately not literal-expressible (see Shared/Big.swift), so XCTest's
// generic overloads can't take a literal against a Big on their own.

func XCTAssertEqual(_ a: Big, _ b: Double, _ message: @autoclosure () -> String = "",
                    file: StaticString = #filePath, line: UInt = #line) {
    // Big is not bit-exact with Double (normalizing divides by powers of ten), so
    // "equal" means equal to 12 significant digits.
    let tolerance = Swift.max(Swift.abs(b), a.magnitude.double) * 1e-12
    XCTAssertTrue((a - Big(b)).magnitude <= Big(tolerance), "\(a) is not \(b). \(message())", file: file, line: line)
}

func XCTAssertEqual(_ a: Big, _ b: Double, accuracy: Double, _ message: @autoclosure () -> String = "",
                    file: StaticString = #filePath, line: UInt = #line) {
    XCTAssertEqual(a.double, b, accuracy: accuracy, message(), file: file, line: line)
}

func XCTAssertEqual(_ a: Big, _ b: Big, accuracy: Double, _ message: @autoclosure () -> String = "",
                    file: StaticString = #filePath, line: UInt = #line) {
    XCTAssertEqual(a.double, b.double, accuracy: accuracy, message(), file: file, line: line)
}

/// `accuracy` given as a Big (e.g. `rate * 1e-9` where `rate` is now Big).
func XCTAssertEqual(_ a: Big, _ b: Big, accuracy: Big, _ message: @autoclosure () -> String = "",
                    file: StaticString = #filePath, line: UInt = #line) {
    XCTAssertTrue((a - b).magnitude <= accuracy.magnitude, "\(a) vs \(b) (±\(accuracy)). \(message())", file: file, line: line)
}

/// Test-only: "didn't run away to Big.max" (Big has no infinity).
extension Big {
    var isFinite: Bool { self < Big.max && self > -Big.max }
}

func XCTAssertEqual(_ a: Big?, _ b: Double, _ message: @autoclosure () -> String = "",
                    file: StaticString = #filePath, line: UInt = #line) {
    guard let a else { return XCTFail("nil is not \(b). \(message())", file: file, line: line) }
    XCTAssertEqual(a, b, message(), file: file, line: line)
}

func XCTAssertGreaterThan(_ a: Big, _ b: Double, _ message: @autoclosure () -> String = "",
                          file: StaticString = #filePath, line: UInt = #line) {
    XCTAssertTrue(a > b, "\(a) is not > \(b). \(message())", file: file, line: line)
}

func XCTAssertGreaterThanOrEqual(_ a: Big, _ b: Double, _ message: @autoclosure () -> String = "",
                                 file: StaticString = #filePath, line: UInt = #line) {
    XCTAssertTrue(a >= b, "\(a) is not >= \(b). \(message())", file: file, line: line)
}

func XCTAssertLessThan(_ a: Big, _ b: Double, _ message: @autoclosure () -> String = "",
                       file: StaticString = #filePath, line: UInt = #line) {
    XCTAssertTrue(a < b, "\(a) is not < \(b). \(message())", file: file, line: line)
}

func XCTAssertLessThanOrEqual(_ a: Big, _ b: Double, _ message: @autoclosure () -> String = "",
                              file: StaticString = #filePath, line: UInt = #line) {
    XCTAssertTrue(a <= b, "\(a) is not <= \(b). \(message())", file: file, line: line)
}
