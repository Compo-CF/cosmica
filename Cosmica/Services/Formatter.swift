import Foundation

/// Compact formatter for cosmic-scale numbers. 1.23K / 4.56M / 7.89B / 1.23T / 4.56Qa…
enum Formatter {
    /// Suffix ladder (powers of 1000). Order: largest threshold first.
    private static let ladder: [(threshold: Double, suffix: String)] = [
        (1e60, "Nv"),  // Novemdecillion
        (1e57, "Oc"),  // Octodecillion
        (1e54, "Sp"),  // Septendecillion
        (1e51, "Sx"),  // Sexdecillion
        (1e48, "Qi"),  // Quindecillion
        (1e45, "Qa"),  // Quattuordecillion
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
