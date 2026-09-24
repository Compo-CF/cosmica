import Foundation

/// v3.0.3 — the slice of game state the home-screen / Lock Screen widget needs.
///
/// Compiled into BOTH the app and the `CosmicaWidget` extension (see project.yml),
/// so it may only depend on Foundation + the other shared files (`OfflineAccrual`,
/// `Formatter`). The app writes it to the shared App Group when it backgrounds;
/// the widget reads it and projects forward in time.
///
/// Projection uses `OfflineAccrual.compute` with the same rate rules the app
/// applies on return (see `GameEngine.applyOffline`), so the number on the widget
/// is the number the "Welcome back" sheet will credit. Offline accrual doesn't
/// simulate auto-buy, so this holds for automation owners too.
struct WidgetSnapshot: Codable, Equatable {
    static let appGroup = "group.com.centricfiber.cosmica"
    static let storageKey = "cosmica.widget.snapshot.v1"
    /// Widget `kind` identifiers — shared so the app can target reloads.
    static let homeKind = "CosmicaHomeWidget"
    static let lockKind = "CosmicaLockWidget"

    /// When the player stopped playing (`GameState.lastSeen` at background).
    var savedAt: Date
    /// ✦/s with the transient boosts (ad boost, cosmic event) divided out.
    var baseRate: Double
    var adBoostMultiplier: Double
    var adBoostExpiresAt: Date?
    var eventMultiplier: Double
    var eventExpiresAt: Date?
    /// Full offline window: base 8h + Cosmic Tree Nightwatch + Chronosphere.
    var offlineCap: TimeInterval
    var cosmicShards: Double
    var prestigeCount: Int
    var cosmosCount: Int
    var tierTitle: String
    var tierSymbol: String
    var lastDailyClaim: Date?

    // MARK: - Projection

    /// ✦/s the app will apply if the player returns at `date`. The app evaluates
    /// boosts at return time and uses that rate for the whole away window, so a
    /// boost that has expired by `date` contributes nothing.
    func rate(at date: Date) -> Double {
        var r = baseRate
        if let exp = adBoostExpiresAt, date < exp { r *= adBoostMultiplier }
        if let exp = eventExpiresAt, date < exp { r *= eventMultiplier }
        return r
    }

    /// Stardust waiting to be collected if the player opens the app at `date`.
    func waiting(at date: Date) -> Double {
        OfflineAccrual.compute(
            now: date,
            lastSeen: savedAt,
            ratePerSecond: rate(at: date),
            extraCap: offlineCap - OfflineAccrual.baseCap
        ).stardustEarned
    }

    /// Moment the offline window fills and earnings stop.
    var fullAt: Date { savedAt.addingTimeInterval(offlineCap) }

    func isFull(at date: Date) -> Bool { date >= fullAt }

    /// 0...1 progress through the offline window.
    func fillFraction(at date: Date) -> Double {
        guard offlineCap > 0 else { return 1 }
        return min(1, max(0, date.timeIntervalSince(savedAt) / offlineCap))
    }

    /// Mirrors `GameEngine.dailyRewardAvailable` (new calendar day since last claim).
    func dailyRewardReady(at date: Date, calendar: Calendar = .current) -> Bool {
        guard let last = lastDailyClaim else { return true }
        return !calendar.isDate(last, inSameDayAs: date)
    }

    /// Timeline entry dates for the next `horizon`: every `step` while stardust is
    /// still climbing, plus the moments the display changes on its own (window
    /// fills, a boost expires, the daily reward resets at midnight).
    func timelineDates(from now: Date,
                       step: TimeInterval = 600,
                       horizon: TimeInterval = 86_400,
                       calendar: Calendar = .current) -> [Date] {
        let end = now.addingTimeInterval(horizon)
        var dates: Set<Date> = [now]
        var t = now.addingTimeInterval(step)
        while t < min(fullAt, end) {
            dates.insert(t)
            t = t.addingTimeInterval(step)
        }
        var keyMoments: [Date] = [fullAt]
        if let exp = adBoostExpiresAt { keyMoments.append(exp) }
        if let exp = eventExpiresAt { keyMoments.append(exp) }
        if let midnight = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) {
            keyMoments.append(midnight)
        }
        for moment in keyMoments where moment > now && moment <= end {
            dates.insert(moment)
        }
        return dates.sorted()
    }

    // MARK: - Storage (App Group UserDefaults)

    static func load(from defaults: UserDefaults? = UserDefaults(suiteName: appGroup)) -> WidgetSnapshot? {
        guard let data = defaults?.data(forKey: storageKey) else { return nil }
        return try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
    }

    func save(to defaults: UserDefaults? = UserDefaults(suiteName: WidgetSnapshot.appGroup)) {
        guard let data = try? JSONEncoder().encode(self) else { return }
        defaults?.set(data, forKey: Self.storageKey)
    }
}
