import Foundation
import Observation

/// v3.5 — Holds the current "More from After Hours Dev Studio" catalog.
///
/// Flow on launch:
///   1. Seed `games` instantly from the on-disk cache (or the bundled fallback
///      if the cache is empty), so the shelf has something to show right away.
///   2. Kick off a background `refresh()` that pulls the latest JSON from
///      GitHub Pages, writes it to disk, and republishes `games`.
///
/// Flow on foreground: another `refresh()` runs, throttled by
/// `minRefreshInterval` so bouncing between apps doesn't hammer the server.
///
/// Flexibility notes:
/// - Adding or removing a game only requires editing the hosted JSON and (for
///   a new game) pushing its icon PNG. No Cosmica rebuild.
/// - Each app passes its own `selfID`, and games with matching `id` or
///   `hiddenFromApps.contains(selfID)` are filtered out, so one catalog serves
///   every app in the portfolio without showing an app its own card.
@MainActor
@Observable
final class StudioShelfProvider {
    /// Filtered + sorted games to display.
    private(set) var games: [StudioGame] = []
    /// Set to true while a network refresh is in flight.
    private(set) var isRefreshing = false
    /// When the last successful refresh finished. nil before the first success.
    private(set) var lastRefreshed: Date?
    /// The last refresh error, if the latest attempt failed. Cleared on success.
    private(set) var lastError: Error?

    /// Slug of the owning app (e.g. "cosmica"). The provider auto-excludes a
    /// game whose `id` matches this, so the shelf never shows the host app.
    let selfID: String
    /// Where the latest catalog is published. Defaults to Cosmica's Pages
    /// bucket; swap in a dedicated Studio domain later without touching callers.
    let catalogURL: URL
    /// Minimum seconds between network refreshes.
    let minRefreshInterval: TimeInterval

    private let session: URLSession
    private let bundle: Bundle
    private let fileManager: FileManager
    private let cacheFileName = "studio-games.json"
    private let bundledResourceName = "studio-games"
    private var rawGames: [StudioGame] = []

    init(selfID: String,
         catalogURL: URL = URL(string: "https://compo-cf.github.io/cosmica/studio-games.json")!,
         minRefreshInterval: TimeInterval = 3_600,
         session: URLSession = .shared,
         bundle: Bundle = .main,
         fileManager: FileManager = .default) {
        self.selfID = selfID
        self.catalogURL = catalogURL
        self.minRefreshInterval = minRefreshInterval
        self.session = session
        self.bundle = bundle
        self.fileManager = fileManager
        // Seed from the best source we have right now — never leaves `games` empty.
        if let cached = loadCached() {
            apply(cached)
        } else if let bundled = loadBundled() {
            apply(bundled)
        }
    }

    /// Fetches the latest catalog and republishes `games`. Throttled; pass
    /// `force: true` to bypass the throttle (e.g. pull-to-refresh).
    func refresh(force: Bool = false) async {
        if isRefreshing { return }
        if !force, let last = lastRefreshed,
           Date().timeIntervalSince(last) < minRefreshInterval { return }
        isRefreshing = true
        defer { isRefreshing = false }

        var request = URLRequest(url: catalogURL)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 10
        do {
            let (data, response) = try await session.data(for: request)
            if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                throw URLError(.badServerResponse)
            }
            let catalog = try decode(data)
            apply(catalog)
            saveCache(data)
            lastRefreshed = Date()
            lastError = nil
        } catch {
            lastError = error
            // Keep whatever we already had; a failed refresh never empties the shelf.
        }
    }

    // MARK: - Filtering / sorting

    private func apply(_ catalog: StudioCatalog) {
        rawGames = catalog.games
        games = catalog.games
            .filter { $0.id != selfID }
            .filter { !($0.hiddenFromApps?.contains(selfID) ?? false) }
            .sorted { lhs, rhs in
                let l = lhs.sortWeight ?? Int.max
                let r = rhs.sortWeight ?? Int.max
                if l != r { return l < r }
                let li = rawGames.firstIndex(of: lhs) ?? 0
                let ri = rawGames.firstIndex(of: rhs) ?? 0
                return li < ri
            }
    }

    private func decode(_ data: Data) throws -> StudioCatalog {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(StudioCatalog.self, from: data)
    }

    // MARK: - Cache + bundled fallback

    private var cacheURL: URL? {
        guard let dir = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first else {
            return nil
        }
        return dir.appendingPathComponent(cacheFileName)
    }

    private func loadCached() -> StudioCatalog? {
        guard let url = cacheURL,
              let data = try? Data(contentsOf: url) else { return nil }
        return try? decode(data)
    }

    private func saveCache(_ data: Data) {
        guard let url = cacheURL else { return }
        try? data.write(to: url, options: .atomic)
    }

    private func loadBundled() -> StudioCatalog? {
        guard let url = bundle.url(forResource: bundledResourceName, withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return nil }
        return try? decode(data)
    }
}
