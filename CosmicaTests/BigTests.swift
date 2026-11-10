import XCTest
@testable import Cosmica

/// v4.0 — the number type that replaces the 1e300 ceiling.
final class BigTests: XCTestCase {

    private func close(_ a: Double, _ b: Double, rel: Double = 1e-12,
                       file: StaticString = #filePath, line: UInt = #line) {
        let scale = Swift.max(Swift.abs(a), Swift.abs(b))
        XCTAssertLessThanOrEqual(Swift.abs(a - b), rel * Swift.max(scale, 1e-300), "\(a) vs \(b)", file: file, line: line)
    }

    // MARK: Normalization & conversion

    func test_normalizes_mantissaIntoOneToTen() {
        for v in [1.0, 9.99, 10, 0.5, 123_456.789, 1e-5, -42, 3e200] {
            let b = Big(v)
            XCTAssertTrue(Swift.abs(b.mantissa) >= 1 && Swift.abs(b.mantissa) < 10, "\(v) → \(b.mantissa)")
            close(b.double, v)
        }
        close(Big(mantissa: 1, exponent: 2.5).double, pow(10, 2.5))
        close(Big(mantissa: 250, exponent: 3).double, 250_000)
    }

    func test_nonFiniteInputs_neverLeakIn() {
        XCTAssertEqual(Big(Double.nan), .zero)
        XCTAssertEqual(Big(Double.infinity), .max)
        XCTAssertEqual(Big(-Double.infinity), -Big.max)
        XCTAssertTrue(Big.max.double.isFinite)
        XCTAssertEqual(Big(5) / Big.zero, .max)
        XCTAssertEqual(Big.zero / Big.zero, .zero)
    }

    // MARK: Arithmetic matches Double in Double's range

    func test_arithmetic_matchesDouble() {
        for _ in 0..<5_000 {
            let x = (Bool.random() ? 1.0 : -1.0) * pow(10, Double.random(in: -20...40))
            let y = (Bool.random() ? 1.0 : -1.0) * pow(10, Double.random(in: -20...40))
            let bx = Big(x), by = Big(y)
            close((bx + by).double, x + y, rel: 1e-9)
            close((bx * by).double, x * y)
            close((bx / by).double, x / y)
            XCTAssertEqual(bx < by, x < y)
            XCTAssertEqual(bx > y, x > y)
        }
    }

    func test_exactCancellation_isZero() {
        XCTAssertEqual(Big(5) - Big(5), .zero)
        let huge = Big(mantissa: 1, exponent: 400)
        XCTAssertTrue((huge - huge).isZero)
    }

    func test_tinyAddend_isAbsorbed_likeDouble() {
        let huge = Big(mantissa: 1, exponent: 500)
        XCTAssertEqual(huge + Big(1), huge)
    }

    // MARK: Past Double

    func test_goesPastDouble() {
        let a = Big(1e300) * Big(1e300)
        XCTAssertEqual(a.exponent, 600)
        XCTAssertFalse(a.fitsInDouble)
        XCTAssertEqual(a.double, .greatestFiniteMagnitude)    // clamped, not ∞
        close(a.log10Value, 600)
        XCTAssertGreaterThan(a, Big(1e300))
        XCTAssertTrue(a > 1e308)
        close((a / Big(1e300)).double, 1e300)
    }

    func test_powersAndRoots_inLogSpace() {
        close(Big(4).squareRoot.double, 2)
        close(Big.power(1.15, 100).double, pow(1.15, 100), rel: 1e-10)
        let cost = Big.power(1.15, 10_000)                     // ≈ 1e607, a late generator price
        close(cost.log10Value, 10_000 * log10(1.15), rel: 1e-12)
        close(Big(mantissa: 1, exponent: 1000).squareRoot.log10Value, 500)
        close(Big.fromLog10(1234.5).log10Value, 1234.5)
        XCTAssertEqual(Big.zero.raised(to: 2), .zero)
        XCTAssertEqual(Big(7).raised(to: 0), .one)
    }

    func test_floored() {
        XCTAssertEqual(Big(12.9).floored, Big(12))
        let huge = Big(mantissa: 1.5, exponent: 40)
        XCTAssertEqual(huge.floored, huge)
    }

    // MARK: Ordering

    func test_ordering_acrossSignsAndExponents() {
        let values: [Big] = [-Big.max, Big(-1e50), Big(-3), Big(-2), .zero, Big(1e-10), .one,
                             Big(9.99), Big(10), Big(1e300), Big(mantissa: 1, exponent: 900), .max]
        for i in values.indices {
            for j in values.indices {
                XCTAssertEqual(values[i] < values[j], i < j, "\(values[i]) vs \(values[j])")
            }
        }
        XCTAssertEqual(Big.larger(Big(3), Big(7)), Big(7))
        XCTAssertEqual(Big.smaller(Big(3), Big(7)), Big(3))
    }

    // MARK: Save format

    func test_decodes_preV4SaveNumbers() throws {
        let json = #"{"a": 123.5, "b": 1e300, "c": 0}"#.data(using: .utf8)!
        let d = try JSONDecoder().decode([String: Big].self, from: json)
        XCTAssertEqual(d["a"], Big(123.5))
        XCTAssertEqual(d["b"], Big(1e300))
        XCTAssertEqual(d["c"], .zero)
    }

    func test_encodes_asNumberWhileItFits_stringPastIt() throws {
        // Fits: a bare JSON number, so a pre-4.0 build can still read the save.
        let small = try JSONEncoder().encode([Big(4.5e12)])
        let smallText = String(data: small, encoding: .utf8) ?? ""
        XCTAssertFalse(smallText.contains("\""), smallText)
        XCTAssertEqual(try JSONDecoder().decode([Double].self, from: small), [4.5e12])

        let huge = Big(mantissa: 1.25, exponent: 456)
        let data = try JSONEncoder().encode([huge])
        XCTAssertEqual(String(data: data, encoding: .utf8), #"["1.25e456"]"#)
        XCTAssertEqual(try JSONDecoder().decode([Big].self, from: data), [huge])
    }

    func test_stringRoundTrip() {
        for b in [Big(mantissa: 3.14159265358979, exponent: 12_345), Big(-2.5), Big(mantissa: 9.99, exponent: -400)] {
            XCTAssertEqual(Big(b.description), b)
        }
        XCTAssertEqual(Big("1e+20"), Big(1e20))
        XCTAssertNil(Big("stardust"))
    }
}
