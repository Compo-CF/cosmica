import Foundation

/// The reward granted (or previewed) for a daily login claim.
struct DailyReward: Equatable {
    let day: Int          // 1…7 position in the reward cycle
    let streak: Int       // consecutive-day streak
    let stardust: Double
    let cosmicShards: Int
    let boostHours: Double

    var summary: String {
        var parts: [String] = []
        if stardust > 0 { parts.append("+\(Formatter.short(stardust)) ✦") }
        if cosmicShards > 0 { parts.append("+\(cosmicShards) ◈") }
        if boostHours > 0 { parts.append("2× boost \(Int(boostHours))h") }
        return parts.joined(separator: "  ·  ")
    }
}
