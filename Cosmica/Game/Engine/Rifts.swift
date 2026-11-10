import Foundation

/// v4.0 — Rifts: challenge runs inside the Omniverse (planning/v4.0-plan.md, phase 3b).
/// Entering a Rift starts a fresh run (like a Big Bang, no shards paid) under one rule.
/// Reaching the goal in that run completes the next tier (3 per Rift) and pays a
/// permanent reward. Leaving early costs nothing but the run.
///
/// The goal scales with the player: tier k needs (0.6, 0.8, 1.0) × the orders of
/// magnitude of their best run ever (at least 1e100), fixed when they enter. So a
/// Rift asks you to match your own record under a handicap, at any stage.
struct Rift: Identifiable, Hashable {
    let id: String
    let title: String
    let rule: String
    let reward: String
    let symbol: String
}

enum RiftCatalog {
    static let dimStarsId = "dim_stars"
    static let silentVoidId = "silent_void"
    static let heavyVeilId = "heavy_veil"
    static let loneHandId = "lone_hand"
    static let shortNightId = "short_night"

    static let maxTier = 3
    static let goalShares: [Double] = [0.6, 0.8, 1.0]
    static let minGoalLog: Double = 100

    // Rule numbers
    static let heavyVeilThreshold = Big(1e100)
    static let heavyVeilStrength: Double = 0.4
    static let loneHandTapBoost: Double = 100
    static let shortNightProductionBoost: Double = 3
    // Reward numbers (per completed tier)
    static let dimStarsRewardPerTier: Double = 10        // generators 1–8
    static let silentVoidRewardPerTier: Double = 1.5     // fragment and spark yield
    static let heavyVeilRewardPerTier: Double = 0.007    // dilation strength, past the Veil cap
    static let loneHandRewardPerTier: Double = 5         // taps
    static let shortNightRewardPerTier: TimeInterval = 12 * 3600

    static let all: [Rift] = [
        Rift(id: dimStarsId, title: "Dim Stars",
             rule: "Generators 9–16 produce nothing.",
             reward: "Generators 1–8 ×10, per tier.", symbol: "moon.stars"),
        Rift(id: silentVoidId, title: "Silent Void",
             rule: "Void Sparks and Reality Fragments give no bonus.",
             reward: "True Cosmos and Multiverse yields ×1.5, per tier.", symbol: "speaker.slash"),
        Rift(id: heavyVeilId, title: "Heavy Veil",
             rule: "Dilation starts at 1e100 and counts each ×10 at 40%.",
             reward: "+0.7% dilation per tier, past Thin the Veil's cap.", symbol: "cloud.fog"),
        Rift(id: loneHandId, title: "Lone Hand",
             rule: "No automation of any kind. Taps are worth ×100.",
             reward: "Taps ×5, per tier.", symbol: "hand.raised"),
        Rift(id: shortNightId, title: "Short Night",
             rule: "No offline earnings. Production ×3.",
             reward: "+12 hours of offline cap, per tier.", symbol: "sunrise"),
    ]

    static func rift(id: String) -> Rift? { all.first { $0.id == id } }

    /// log10 goal for the next tier of `id` given the best run ever.
    static func goalLog(tierIndex: Int, bestRunLog: Double) -> Double {
        let share = goalShares[min(max(tierIndex, 0), goalShares.count - 1)]
        return max(minGoalLog, (share * bestRunLog).rounded(.up))
    }
}
