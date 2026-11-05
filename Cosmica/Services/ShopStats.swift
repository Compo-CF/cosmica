import Foundation
import CloudKit

/// v3.4 — anonymous Shop counts, so purchases can be read against how often
/// each item is actually seen. Before this the only Shop data was Apple's
/// sales report: what sold, never what was shown and passed over.
///
/// What is counted, per UTC day: Shop opens, each card scrolled into view,
/// each buy / watch-ad button tapped, and each purchase or ad reward that
/// completed. Nothing else: no identifiers, no game state, no device data.
///
/// Where it goes: one record per device per day in Cosmica's own CloudKit
/// public database (record type `ShopDay`). The record name is a fresh random
/// UUID each day, so two days from one phone can't be linked to each other.
/// Upload needs an iCloud account; without one the counts simply stay on the
/// device and age out after two weeks. Settings > Legal has an off switch,
/// which also deletes what's stored locally.
///
/// App Privacy: "Usage Data > Product Interaction", not linked to the user,
/// used for analytics. Described in PrivacyPolicyView and docs/privacy.md.
@MainActor
final class ShopStats {
    static let shared = ShopStats()

    static let enabledKey = "cosmica.shopstats.enabled"
    static let containerId = "iCloud.com.centricfiber.cosmica"
    static let recordType = "ShopDay"

    private static let countsKey = "cosmica.shopstats.days.v1"
    private static let namesKey = "cosmica.shopstats.ids.v1"
    private static let dirtyKey = "cosmica.shopstats.dirty.v1"
    /// Days kept on the device (and retried) before they're dropped.
    static let keepDays = 14
    /// At most one upload attempt per this many seconds (unless forced).
    private static let uploadGap: TimeInterval = 600

    private let defaults: UserDefaults
    private var uploading = false
    private var lastUploadAt: Date?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var enabled: Bool { defaults.object(forKey: Self.enabledKey) as? Bool ?? true }

    // MARK: - Events

    func open()                    { record("open") }
    func view(_ card: String)      { record("view.\(card)") }
    func tap(_ productId: String)  { record("tap.\(Self.key(productId))") }
    func buy(_ productId: String)  { record("buy.\(Self.key(productId))") }
    func ad(_ placement: String)   { record("ad.\(placement)") }
    func reward(_ placement: String) { record("reward.\(placement)") }

    /// Short name for a product id: "com.centricfiber.cosmica.timewarp_8h" → "timewarp_8h".
    static func key(_ productId: String) -> String {
        productId.replacingOccurrences(of: "com.centricfiber.cosmica.", with: "")
    }

    func record(_ event: String, now: Date = Date()) {
        guard enabled else { return }
        let day = Self.day(now)
        var all = counts
        all[day, default: [:]][event, default: 0] += 1
        counts = all
        var dirty = dirtyDays
        dirty.insert(day)
        dirtyDays = dirty
    }

    /// Stops counting: forgets everything held on the device.
    func clear() {
        defaults.removeObject(forKey: Self.countsKey)
        defaults.removeObject(forKey: Self.namesKey)
        defaults.removeObject(forKey: Self.dirtyKey)
    }

    // MARK: - Upload

    /// Sends every day that changed since its last upload. Safe to call often:
    /// throttled, a no-op when off, offline or signed out of iCloud, and a
    /// failed day stays queued for the next try.
    func flush(force: Bool = false) async {
        guard enabled, !uploading else { return }
        if !force, let last = lastUploadAt, Date().timeIntervalSince(last) < Self.uploadGap { return }
        prune()
        let pending = dirtyDays
        guard !pending.isEmpty else { return }
        uploading = true
        defer { uploading = false }
        lastUploadAt = Date()

        let container = CKContainer(identifier: Self.containerId)
        guard (try? await container.accountStatus()) == .available else { return }

        let snapshot = counts
        var names = recordNames
        var records: [CKRecord] = []
        var dayOf: [String: String] = [:]
        for day in pending {
            guard let c = snapshot[day],
                  let json = try? JSONEncoder().encode(c),
                  let text = String(data: json, encoding: .utf8) else { continue }
            let name = names[day] ?? UUID().uuidString
            names[day] = name
            dayOf[name] = day
            let record = CKRecord(recordType: Self.recordType, recordID: CKRecord.ID(recordName: name))
            record["day"] = day as CKRecordValue
            record["version"] = Self.appVersion as CKRecordValue
            record["counts"] = text as CKRecordValue
            records.append(record)
        }
        recordNames = names
        guard !records.isEmpty else { return }

        do {
            // .allKeys overwrites this device's record for the day without a
            // fetch first; the counts field always carries the full day.
            let (saved, _) = try await container.publicCloudDatabase.modifyRecords(
                saving: records, deleting: [], savePolicy: .allKeys, atomically: false)
            var dirty = dirtyDays
            let now = counts
            for (id, result) in saved {
                guard case .success = result, let day = dayOf[id.recordName] else { continue }
                // Only clear a day that didn't change while it was uploading.
                if now[day] == snapshot[day] { dirty.remove(day) }
            }
            dirtyDays = dirty
        } catch {
            // Network or iCloud trouble: everything stays queued.
        }
    }

    // MARK: - Storage

    static func day(_ date: Date) -> String {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .iso8601)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }

    private static var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
    }

    /// Internal (not private) so tests can read what was counted.
    var counts: [String: [String: Int]] {
        get { decode(Self.countsKey) ?? [:] }
        set { encode(newValue, Self.countsKey) }
    }

    private var recordNames: [String: String] {
        get { decode(Self.namesKey) ?? [:] }
        set { encode(newValue, Self.namesKey) }
    }

    private var dirtyDays: Set<String> {
        get { Set(decode(Self.dirtyKey) as [String]? ?? []) }
        set { encode(Array(newValue).sorted(), Self.dirtyKey) }
    }

    /// Drops days older than `keepDays`, uploaded or not.
    func prune(now: Date = Date()) {
        let cutoff = Self.day(now.addingTimeInterval(-Double(Self.keepDays) * 86_400))
        counts = counts.filter { $0.key >= cutoff }
        recordNames = recordNames.filter { $0.key >= cutoff }
        dirtyDays = dirtyDays.filter { $0 >= cutoff }
    }

    private func decode<T: Decodable>(_ key: String) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    private func encode<T: Encodable>(_ value: T, _ key: String) {
        if let data = try? JSONEncoder().encode(value) { defaults.set(data, forKey: key) }
    }
}
