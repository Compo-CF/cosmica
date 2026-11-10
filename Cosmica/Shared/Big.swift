import Foundation

/// v4.0 — a number that keeps going past Double's ~1.8e308.
///
/// Stored as `mantissa × 10^exponent` with |mantissa| in [1, 10) (or exactly 0)
/// and an integer-valued `exponent` held in a Double, so values reach about
/// 1e(9e15). Precision is a Double's (~15 significant digits), which is all an
/// idle game needs: when two values differ by more than 17 orders of magnitude,
/// adding the smaller one does nothing, exactly as with Double.
///
/// Non-finite inputs never leak in: NaN becomes 0 and ±∞ becomes ±`max`, so a
/// runaway formula lands on a huge-but-valid number instead of freezing a save
/// (the reason 3.2 had to cap Stardust at 1e300).
///
/// Save format: a plain JSON number while |exponent| < 300, so every pre-4.0 save
/// decodes unchanged and 4.0 saves stay readable by older builds until a player
/// actually passes 1e300. Past that it is a string, "1.2345e456".
///
/// Deliberately NOT ExpressibleByIntegerLiteral/FloatLiteral: with the mixed
/// Big/Double operators below, a literal would make `x > 0` ambiguous. Write
/// `Big.zero`, `Big(1e12)`, or compare against a Double directly.
///
/// No top-level `max`/`pow`/`sqrt` helpers on purpose: a module-level function
/// with those names would shadow the standard ones for every Double in the app.
///
/// Foundation-only: compiled into the widget target as well (project.yml).
struct Big: Sendable, Hashable {
    private(set) var mantissa: Double
    private(set) var exponent: Double

    // MARK: Constants

    static let zero = Big(normalizedMantissa: 0, exponent: 0)
    static let one = Big(normalizedMantissa: 1, exponent: 0)
    /// Largest value, about 1e(9e15). Stands in for +∞.
    static let max = Big(normalizedMantissa: 9.999_999_999_999_99, exponent: maxExponent)
    static let maxExponent: Double = 9e15

    /// Exponent at which a value no longer fits in a Double.
    private static let doubleExponentLimit: Double = 308
    /// Adding a value this many orders of magnitude smaller changes nothing.
    private static let precisionDigits: Double = 17

    // MARK: Init

    /// Exact conversion from a Double (NaN → 0, ±∞ → ±max).
    init(_ value: Double) {
        if value.isNaN || value == 0 {
            self = .zero
        } else if value.isInfinite {
            self = value > 0 ? .max : -Big.max
        } else {
            self.init(mantissa: value, exponent: 0)
        }
    }

    init(_ value: Int) { self.init(Double(value)) }

    /// Any mantissa/exponent pair; normalizes so |mantissa| is in [1, 10).
    init(mantissa: Double, exponent: Double) {
        if mantissa.isNaN || exponent.isNaN || mantissa == 0 {
            self = .zero
            return
        }
        if mantissa.isInfinite {
            self = mantissa > 0 ? .max : -Big.max
            return
        }
        if exponent.isInfinite {
            self = exponent < 0 ? .zero : (mantissa > 0 ? .max : -Big.max)
            return
        }
        var m = mantissa
        var e = exponent.rounded(.down)
        // Fold a fractional exponent into the mantissa.
        let frac = exponent - e
        if frac != 0 { m *= Foundation.pow(10, frac) }
        if Swift.abs(m).isNormal {
            let shift = Foundation.log10(Swift.abs(m)).rounded(.down)
            if shift != 0 {
                m /= Foundation.pow(10, shift)
                e += shift
            }
        }
        // log10 rounding can leave the mantissa a hair outside [1, 10).
        if Swift.abs(m) >= 10 { m /= 10; e += 1 }
        if Swift.abs(m) < 1 { m *= 10; e -= 1 }
        if e > Big.maxExponent {
            self = m > 0 ? .max : -Big.max
        } else if e < -Big.maxExponent {
            self = .zero
        } else {
            self.init(normalizedMantissa: m, exponent: e)
        }
    }

    private init(normalizedMantissa: Double, exponent: Double) {
        self.mantissa = normalizedMantissa
        self.exponent = exponent
    }

    // MARK: Properties

    var isZero: Bool { mantissa == 0 }
    var sign: Int { mantissa > 0 ? 1 : (mantissa < 0 ? -1 : 0) }
    var magnitude: Big { mantissa < 0 ? -self : self }

    /// The value as a Double, clamped to ±greatestFiniteMagnitude (never ∞/NaN).
    var double: Double {
        if isZero { return 0 }
        if exponent > Big.doubleExponentLimit {
            return mantissa > 0 ? .greatestFiniteMagnitude : -.greatestFiniteMagnitude
        }
        if exponent < -323 { return 0 }
        let v = mantissa * Foundation.pow(10, exponent)
        if v.isFinite { return v }
        return mantissa > 0 ? .greatestFiniteMagnitude : -.greatestFiniteMagnitude
    }

    /// Whether `double` is exact (no clamping).
    var fitsInDouble: Bool { exponent < Big.doubleExponentLimit }

    /// log10 of the absolute value (−∞ for zero). Works at any size.
    var log10Value: Double {
        isZero ? -.infinity : exponent + Foundation.log10(Swift.abs(mantissa))
    }

    // MARK: Rounding

    /// Rounded toward −∞. Values ≥ 1e16 are already whole at Double precision.
    var floored: Big {
        exponent >= 16 ? self : Big(double.rounded(.down))
    }

    // MARK: Powers

    /// |self|^p, computed in log space so it never overflows.
    func raised(to p: Double) -> Big {
        if isZero { return p > 0 ? .zero : .one }
        if p == 0 { return .one }
        let l = log10Value * p
        if l.isNaN { return .zero }
        return Big.fromLog10(l)
    }

    var squareRoot: Big { raised(to: 0.5) }

    /// 10^l for any real l.
    static func fromLog10(_ l: Double) -> Big {
        if l.isNaN { return .zero }
        if l > maxExponent { return .max }
        if l < -maxExponent { return .zero }
        let e = l.rounded(.down)
        return Big(mantissa: Foundation.pow(10, l - e), exponent: e)
    }

    /// base^p for a Double base, without overflowing (e.g. a cost curve 1.15^5000).
    static func power(_ base: Double, _ p: Double) -> Big {
        Big(base).raised(to: p)
    }
}

// MARK: - Arithmetic

extension Big: AdditiveArithmetic {
    static func + (a: Big, b: Big) -> Big {
        if a.isZero { return b }
        if b.isZero { return a }
        let (hi, lo) = a.exponent >= b.exponent ? (a, b) : (b, a)
        let diff = hi.exponent - lo.exponent
        if diff > precisionDigits { return hi }
        return Big(mantissa: hi.mantissa + lo.mantissa * Foundation.pow(10, -diff), exponent: hi.exponent)
    }

    static prefix func - (a: Big) -> Big {
        Big(normalizedMantissa: -a.mantissa, exponent: a.exponent)
    }

    static func - (a: Big, b: Big) -> Big { a + (-b) }

    static func += (a: inout Big, b: Big) { a = a + b }
    static func -= (a: inout Big, b: Big) { a = a - b }
}

extension Big {
    static func * (a: Big, b: Big) -> Big {
        if a.isZero || b.isZero { return .zero }
        return Big(mantissa: a.mantissa * b.mantissa, exponent: a.exponent + b.exponent)
    }

    /// Division by zero gives ±max (0/0 gives 0), never ∞ or NaN.
    static func / (a: Big, b: Big) -> Big {
        if a.isZero { return .zero }
        if b.isZero { return a.mantissa > 0 ? .max : -Big.max }
        return Big(mantissa: a.mantissa / b.mantissa, exponent: a.exponent - b.exponent)
    }

    static func *= (a: inout Big, b: Big) { a = a * b }
    static func /= (a: inout Big, b: Big) { a = a / b }

    // Mixed with Double, so call sites can write `stardust * 2` or `cost / 1.5`.
    static func + (a: Big, b: Double) -> Big { a + Big(b) }
    static func - (a: Big, b: Double) -> Big { a - Big(b) }
    static func * (a: Big, b: Double) -> Big { a * Big(b) }
    static func / (a: Big, b: Double) -> Big { a / Big(b) }
    static func + (a: Double, b: Big) -> Big { Big(a) + b }
    static func - (a: Double, b: Big) -> Big { Big(a) - b }
    static func * (a: Double, b: Big) -> Big { Big(a) * b }
    static func / (a: Double, b: Big) -> Big { Big(a) / b }
    static func += (a: inout Big, b: Double) { a = a + Big(b) }
    static func -= (a: inout Big, b: Double) { a = a - Big(b) }
    static func *= (a: inout Big, b: Double) { a = a * Big(b) }
    static func /= (a: inout Big, b: Double) { a = a / Big(b) }
}

// MARK: - Comparison

extension Big: Comparable {
    static func < (a: Big, b: Big) -> Bool {
        if a.sign != b.sign { return a.sign < b.sign }
        if a.isZero { return false }   // both zero
        if a.exponent != b.exponent {
            // Positive: bigger exponent is bigger. Negative: the reverse.
            return a.sign > 0 ? a.exponent < b.exponent : a.exponent > b.exponent
        }
        return a.mantissa < b.mantissa
    }

    static func == (a: Big, b: Double) -> Bool { a == Big(b) }
    static func != (a: Big, b: Double) -> Bool { a != Big(b) }
    static func < (a: Big, b: Double) -> Bool { a < Big(b) }
    static func > (a: Big, b: Double) -> Bool { a > Big(b) }
    static func <= (a: Big, b: Double) -> Bool { a <= Big(b) }
    static func >= (a: Big, b: Double) -> Bool { a >= Big(b) }
    static func < (a: Double, b: Big) -> Bool { Big(a) < b }
    static func > (a: Double, b: Big) -> Bool { Big(a) > b }
    static func <= (a: Double, b: Big) -> Bool { Big(a) <= b }
    static func >= (a: Double, b: Big) -> Bool { Big(a) >= b }

    /// Larger / smaller of two values (static, so it never shadows Swift.max/min).
    static func larger(_ a: Big, _ b: Big) -> Big { a < b ? b : a }
    static func smaller(_ a: Big, _ b: Big) -> Big { a < b ? a : b }
}

// MARK: - Text

extension Big: CustomStringConvertible, LosslessStringConvertible {
    /// "1.23456789012345e456" (round-trips through `init?(_:)`).
    var description: String {
        if isZero { return "0" }
        return String(format: "%.15ge%.0f", mantissa, exponent)
    }

    /// Parses "1.23e456", "1.23E456", "12345" or "1e+20".
    init?(_ text: String) {
        let t = text.trimmingCharacters(in: .whitespaces)
        // Plain numbers go through Double. Anything with an exponent is split, since
        // Double("9.99e-400") quietly underflows to 0 and Double("1e400") to ∞.
        if !t.lowercased().contains("e"), let d = Double(t), d.isFinite {
            self.init(d)
            return
        }
        let parts = t.lowercased().split(separator: "e", maxSplits: 1, omittingEmptySubsequences: false)
        guard parts.count == 2,
              let m = Double(parts[0]), m.isFinite,
              let e = Double(parts[1].replacingOccurrences(of: "+", with: "")), e.isFinite
        else { return nil }
        self.init(mantissa: m, exponent: e)
    }
}

// MARK: - Codable

extension Big: Codable {
    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let d = try? c.decode(Double.self) {
            self.init(d)
        } else {
            let s = try c.decode(String.self)
            guard let v = Big(s) else {
                throw DecodingError.dataCorruptedError(in: c, debugDescription: "Not a number: \(s)")
            }
            self = v
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        if Swift.abs(exponent) < 300 {
            try c.encode(double)
        } else {
            try c.encode(description)
        }
    }
}
