import Foundation

/// A short, buff-window event that periodically kicks in during gameplay to add
/// session pull. Only one event runs at a time; the scheduler in `GameEngine` rolls
/// a new one when the previous window ends.
struct CosmicEvent: Identifiable, Codable, Hashable {
    let id: String              // stable id used to look up the effect at runtime
    let name: String
    let detail: String
    let symbol: String
    /// Base duration in seconds. Actual expiry is stored on GameState as an absolute Date.
    let duration: TimeInterval
    /// What the event boosts. Only one dimension per event to keep the buff readable.
    let effect: CosmicEventEffect
}

enum CosmicEventEffect: Codable, Hashable {
    /// A flat multiplier on stardustPerSecond for the window's duration.
    case stardustPerSecond(multiplier: Double)
    /// A flat multiplier on tap value.
    case tapValue(multiplier: Double)
    /// A flat multiplier on the Cosmic Shard yield of the next Big Bang while active.
    case bigBangYield(multiplier: Double)
    /// A flat multiplier on Cosmic Shard yield of daily rewards / carriers / IAPs
    /// (any grantShards call). Applies only while active.
    case shardGrantMultiplier(multiplier: Double)
}

enum CosmicEventCatalog {
    static let events: [CosmicEvent] = [
        CosmicEvent(id: "supernova",   name: "Supernova",   detail: "2× Stardust per second", symbol: "sparkles",         duration: 300, effect: .stardustPerSecond(multiplier: 2.0)),
        CosmicEvent(id: "meteor",      name: "Meteor Shower", detail: "3× tap value",         symbol: "sparkle.magnifyingglass", duration: 180, effect: .tapValue(multiplier: 3.0)),
        CosmicEvent(id: "gravity",     name: "Gravity Well", detail: "1.5× ✦/s and 1.5× taps", symbol: "circle.hexagongrid.fill", duration: 240, effect: .stardustPerSecond(multiplier: 1.5)),
        CosmicEvent(id: "wormhole",    name: "Wormhole",     detail: "2× Cosmic Shards from any source", symbol: "tornado", duration: 300, effect: .shardGrantMultiplier(multiplier: 2.0)),
        CosmicEvent(id: "big_bang",    name: "Big Bang Echo", detail: "+50% Cosmic Shards on next Big Bang", symbol: "burst.fill", duration: 600, effect: .bigBangYield(multiplier: 1.5)),
    ]

    static func event(id: String) -> CosmicEvent? {
        events.first { $0.id == id }
    }
}

/// Pure functions for event scheduling — how often events roll, how long between them.
/// The engine consumes these; keeping them here keeps balance in one place.
enum CosmicEventScheduler {
    /// Minimum wait between events after one ends. Adds a "dry spell" so events feel
    /// like rewards, not constant noise.
    static let cooldown: TimeInterval = 15 * 60

    /// Extra jitter added on top of the cooldown, so events don't fire on a clockwork
    /// schedule. Range: 0 … maxJitter seconds.
    static let maxJitter: TimeInterval = 30 * 60

    /// Whether the given now / lastEventEnd is past the cooldown so a new event can roll.
    static func canRoll(now: Date, lastEventEnd: Date?) -> Bool {
        guard let last = lastEventEnd else { return true }
        return now.timeIntervalSince(last) >= cooldown
    }

    /// Pick an event deterministically from `now` using a simple hash. Determinism keeps
    /// tests trivial and prevents `random()` calls that would break the no-Date-now rule
    /// for saved-workflow replay in other tooling.
    static func rollEvent(now: Date) -> CosmicEvent {
        let events = CosmicEventCatalog.events
        let bucket = Int(now.timeIntervalSince1970) / 60
        let idx = ((bucket % events.count) + events.count) % events.count
        return events[idx]
    }

    /// Multiplier to apply to a stardust-per-second read while `active` is running.
    static func stardustPerSecondMultiplier(_ active: CosmicEvent?) -> Double {
        guard let e = active else { return 1.0 }
        if case .stardustPerSecond(let m) = e.effect { return m }
        return 1.0
    }

    /// Multiplier to apply to a tap value while `active` is running.
    static func tapMultiplier(_ active: CosmicEvent?) -> Double {
        guard let e = active else { return 1.0 }
        if case .tapValue(let m) = e.effect { return m }
        return 1.0
    }

    /// Multiplier applied to Cosmic Shard grants while `active` is running.
    static func shardGrantMultiplier(_ active: CosmicEvent?) -> Double {
        guard let e = active else { return 1.0 }
        if case .shardGrantMultiplier(let m) = e.effect { return m }
        return 1.0
    }

    /// Multiplier applied to Big Bang shard yield while `active` is running.
    static func bigBangYieldMultiplier(_ active: CosmicEvent?) -> Double {
        guard let e = active else { return 1.0 }
        if case .bigBangYield(let m) = e.effect { return m }
        return 1.0
    }
}
