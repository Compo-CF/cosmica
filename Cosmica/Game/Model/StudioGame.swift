import Foundation

/// v3.5 — one game listed in the "More from After Hours Dev Studio" shelf.
///
/// The authoritative list lives at
/// https://compo-cf.github.io/cosmica/studio-games.json and is fetched by
/// `StudioShelfProvider`. A bundled copy ships in `Resources/studio-games.json`
/// so the first launch (and any launch without network) still has data.
///
/// Every optional field uses `decodeIfPresent` so adding new fields on the
/// server never breaks older binaries that haven't been updated yet.
struct StudioGame: Codable, Identifiable, Hashable, Sendable {
    /// Slug, lowercase, kebab-free. Used as the self-exclusion key and in
    /// ShopStats event names, so changing it detaches historical counts.
    let id: String
    /// Apple App Store numeric id, as a string for safety with large values.
    let appStoreID: String
    let name: String
    let tagline: String
    /// Fully-qualified URL to a square icon PNG, 512x512 recommended.
    /// Served from the Studio Pages bucket so new games don't need an app ship.
    let iconURL: URL
    /// Lower goes earlier. Omit to sort by position in the JSON.
    var sortWeight: Int?
    /// Free-form tags for future filtering, e.g. ["idle", "casual"]. Not shown.
    var audienceTags: [String]?
    /// App-side override: list `selfID` of any app that should NOT display this
    /// card. The owning app's own slug is always auto-filtered so a shelf never
    /// shows the app it's inside.
    var hiddenFromApps: [String]?
    /// Optional cutoff for "Featured" treatment (not yet surfaced in the view).
    var featuredUntil: Date?

    enum CodingKeys: String, CodingKey {
        case id, appStoreID, name, tagline, iconURL
        case sortWeight, audienceTags, hiddenFromApps, featuredUntil
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id             = try c.decode(String.self, forKey: .id)
        appStoreID     = try c.decode(String.self, forKey: .appStoreID)
        name           = try c.decode(String.self, forKey: .name)
        tagline        = try c.decode(String.self, forKey: .tagline)
        iconURL        = try c.decode(URL.self,    forKey: .iconURL)
        sortWeight     = try c.decodeIfPresent(Int.self,       forKey: .sortWeight)
        audienceTags   = try c.decodeIfPresent([String].self,  forKey: .audienceTags)
        hiddenFromApps = try c.decodeIfPresent([String].self,  forKey: .hiddenFromApps)
        featuredUntil  = try c.decodeIfPresent(Date.self,      forKey: .featuredUntil)
    }

    init(id: String, appStoreID: String, name: String, tagline: String, iconURL: URL,
         sortWeight: Int? = nil, audienceTags: [String]? = nil,
         hiddenFromApps: [String]? = nil, featuredUntil: Date? = nil) {
        self.id = id
        self.appStoreID = appStoreID
        self.name = name
        self.tagline = tagline
        self.iconURL = iconURL
        self.sortWeight = sortWeight
        self.audienceTags = audienceTags
        self.hiddenFromApps = hiddenFromApps
        self.featuredUntil = featuredUntil
    }
}

/// Wire format for the hosted JSON. Keeps room to add catalog-level fields
/// (e.g. a global "paused" flag) without touching the per-game schema.
struct StudioCatalog: Codable, Sendable {
    let version: Int
    let updated: String?
    let games: [StudioGame]
}
