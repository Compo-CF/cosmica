import Foundation

/// The reward granted (or previewed) for a daily login claim.
struct DailyReward: Equatable {
    let day: Int          // 1…7 position in the reward cycle
    let streak: Int       // consecutive-day streak
    let stardust: Big
    let cosmicShards: Int
    let boostHours: Double

    var summary: String {
        var parts: [String] = []
        if stardust > 0 { parts.append("+\(Formatter.short(stardust)) ✦") }
        if cosmicShards > 0 { parts.append("+\(cosmicShards) ◈") }
        if boostHours > 0 { parts.append("2× boost \(Int(boostHours))h") }
        return parts.joined(separator: "  ·  ")
    }

    /// v3.4.1 — the same reward with every part multiplied (the ×2 ad claim).
    func scaled(by m: Double) -> DailyReward {
        guard m != 1 else { return self }
        return DailyReward(day: day, streak: streak, stardust: stardust * m,
                           cosmicShards: Int((Double(cosmicShards) * m).rounded()),
                           boostHours: boostHours * m)
    }
}
