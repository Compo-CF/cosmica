import Foundation

/// Compact formatter for cosmic-scale numbers. 1.23K / 4.56M / 7.89B / 1.23T / 4.56Qa…
enum Formatter {
    /// Suffix ladder (powers of 1000). Order: largest threshold first.
    ///
    /// The -decillion tier (1e36 through 1e60) uses `d`-suffixed abbreviations
    /// so it doesn't collide with the base -illion tier below. Earlier builds
    /// used "Sx" for both 1e21 (Sextillion) and 1e51 (Sexdecillion), which made
    /// endgame numbers LOOK stuck as they climbed from one to the other — the
    /// value was growing, the label just wasn't.
    private static let ladder: [(threshold: Double, suffix: String)] = [
        (1e63, "Vg"),  // Vigintillion (v3.2)
        (1e60, "Nvd"), // Novemdecillion
        (1e57, "Ocd"), // Octodecillion
        (1e54, "Spd"), // Septendecillion
        (1e51, "Sxd"), // Sexdecillion
        (1e48, "Qid"), // Quindecillion
        (1e45, "Qad"), // Quattuordecillion
        (1e42, "Td"),  // Tredecillion
        (1e39, "Dd"),  // Duodecillion
        (1e36, "Ud"),  // Undecillion
        (1e33, "Dc"),  // Decillion
        (1e30, "No"),  // Nonillion
        (1e27, "Oc"),  // Octillion
        (1e24, "Sp"),  // Septillion
        (1e21, "Sx"),  // Sextillion
        (1e18, "Qi"),  // Quintillion
        (1e15, "Qa"),  // Quadrillion
        (1e12, "T"),
        (1e9,  "B"),
        (1e6,  "M"),
        (1e3,  "K"),
    ]

    /// Compact short form. Negative numbers preserved.
    static func short(_ value: Double) -> String {
        guard value.isFinite else { return "∞" }
        let abs = Swift.abs(value)
        let sign = value < 0 ? "-" : ""
        if abs < 1000 {
            return "\(sign)\(Int(abs.rounded()))"
        }
        // v3.2 — past the named suffixes, scientific ("4.82e71") instead of an
        // ever-growing "48213Vg" that reads as if the number had stopped.
        if abs >= scientificFrom {
            var exponent = Int(log10(abs).rounded(.down))
            var mantissa = abs / pow(10, Double(exponent))
            if mantissa >= 9.995 { mantissa /= 10; exponent += 1 }
            return String(format: "%@%.2fe%d", sign, mantissa, exponent)
        }
        for (threshold, suffix) in ladder {
            if abs >= threshold {
                let scaled = abs / threshold
                if scaled >= 100 {
                    return String(format: "%@%.0f%@", sign, scaled, suffix)
                } else if scaled >= 10 {
                    return String(format: "%@%.1f%@", sign, scaled, suffix)
                } else {
                    return String(format: "%@%.2f%@", sign, scaled, suffix)
                }
            }
        }
        return String(format: "%@%.0f", sign, abs)
    }

    /// First value shown in scientific notation (1000 × the top suffix).
    static let scientificFrom: Double = 1e66

    /// "×1.25" for everyday multipliers; "×4.51Qa" once they get large, so a
    /// late-game shard or fragment multiplier never prints 20 digits.
    static func multiplier(_ value: Double) -> String {
        guard value.isFinite else { return "×∞" }
        return value < 1000 ? String(format: "×%.2f", value) : "×" + short(value)
    }

    /// Whole-number count with grouping ("1,000"), switching to `short` at a million.
    static func count(_ value: Double) -> String {
        guard value.isFinite else { return "∞" }
        guard Swift.abs(value) < 1e6 else { return short(value) }
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 0
        return f.string(from: NSNumber(value: value.rounded())) ?? "\(Int(value.rounded()))"
    }

    /// Duration like "8h 23m" / "47m 12s" / "1d 4h".
    static func duration(_ seconds: TimeInterval) -> String {
        let s = Int(seconds)
        let days = s / 86_400
        let hours = (s % 86_400) / 3_600
        let mins = (s % 3_600) / 60
        let secs = s % 60
        if days > 0 { return "\(days)d \(hours)h" }
        if hours > 0 { return "\(hours)h \(mins)m" }
        if mins > 0 { return "\(mins)m \(secs)s" }
        return "\(secs)s"
    }
}
