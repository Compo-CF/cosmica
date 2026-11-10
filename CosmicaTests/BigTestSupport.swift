import XCTest
@testable import Cosmica

// v4.0 — assertions that compare a `Big` with a Double (usually a literal), so the
// pre-4.0 tests read the same: `XCTAssertEqual(state.cosmicShards, 35)`.
// `Big` is deliberately not literal-expressible (see Shared/Big.swift), so XCTest's
// generic overloads can't take a literal against a Big on their own.

func XCTAssertEqual(_ a: Big, _ b: Double, _ message: @autoclosure () -> String = "",
                    file: StaticString = #filePath, line: UInt = #line) {
    XCTAssertTrue(a == Big(b), "\(a) is not \(b). \(message())", file: file, line: line)
}

func XCTAssertEqual(_ a: Big, _ b: Double, accuracy: Double, _ message: @autoclosure () -> String = "",
                    file: StaticString = #filePath, line: UInt = #line) {
    XCTAssertEqual(a.double, b, accuracy: accuracy, message(), file: file, line: line)
}

func XCTAssertEqual(_ a: Big, _ b: Big, accuracy: Double, _ message: @autoclosure () -> String = "",
                    file: StaticString = #filePath, line: UInt = #line) {
    XCTAssertEqual(a.double, b.double, accuracy: accuracy, message(), file: file, line: line)
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
