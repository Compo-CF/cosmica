# Cosmica

> Idle universe — discover stars, build telescopes, ascend through cosmic tiers, never stop expanding.

A SwiftUI idle game for iOS 17+. Free with rewarded ads; one-time IAP removes banner & interstitial ads.

## Concept

You start with a backyard telescope. Each generator type produces Stardust (✦) automatically. Spend Stardust to buy more generators and upgrades. When you cross the prestige threshold, **Big Bang** resets your generators in exchange for **Cosmic Shards** (◈) — permanent +2% earnings each, compounding.

Seven tiers map to lifetime Stardust milestones:

| Tier | Lifetime ✦ | Permanent multiplier |
|------|---|---|
| Stargazer | 0 | 1.0× |
| Astronomer | 1e5 | 1.25× |
| Astrophysicist | 1e8 | 1.6× |
| Cosmologist | 1e11 | 2.0× |
| Galactic Cartographer | 1e14 | 2.75× |
| Architect of the Void | 1e17 | 4.0× |
| Demiurge | 1e20 | 6.0× |

Tiers survive Big Bang — they are the long-arc reward. Cosmic Shards are the short-arc reward.

## Tech stack

- **SwiftUI** + Swift 5.9, **iOS 17+**
- **Observation** (`@Observable`) — no Combine
- **Codable structs** + JSON file persistence (no SwiftData — cleaner CloudKit sync)
- **CloudKit** private DB for cross-device save sync
- **StoreKit 2** for the non-consumable Remove Ads IAP
- **GameKit** for leaderboards + achievements
- **Google Mobile Ads SDK** (via Swift Package Manager) for banner + rewarded + interstitial
- **XcodeGen** for project generation (no committed `.xcodeproj`)

No custom backend. CloudKit + Game Center cover sync and social — both are free, both scale with the user's iCloud account.

## Build on MacInCloud

Per your existing workflow (xcodegen at `~/bin`):

```bash
git clone https://github.com/Compo-CF/cosmica.git
cd cosmica
xcodegen generate
open Cosmica.xcodeproj
```

In Xcode:
1. Select the **Cosmica** scheme, choose a simulator or your device.
2. The Google Mobile Ads SDK pulls in via Swift Package Manager on first build (a minute or two).
3. Build & run.

### Before submitting to App Store

1. **AdMob app ID & ad unit IDs** — `Cosmica/Services/AdManager.swift` currently uses Google's test IDs. Replace with your real IDs from https://apps.admob.com. Add the AdMob App ID to `Cosmica/Resources/Info.plist` under `GADApplicationIdentifier`.
2. **App Tracking Transparency** — `Info.plist` already includes `NSUserTrackingUsageDescription`. Customize the copy if desired.
3. **StoreKit product** — create non-consumable `com.centricfiber.cosmica.removeads` ($2.99) in App Store Connect.
4. **CloudKit container** — set up `iCloud.com.centricfiber.cosmica` in the Apple Developer portal and tick the iCloud capability in the project. Push the schema once from your dev device (CloudKit dashboard → Deploy Schema to Production before launch).
5. **Game Center leaderboards** — create in App Store Connect with these IDs (must match `GameCenterManager.swift`):
   - `cosmica.lifetime_stardust`
   - `cosmica.prestige_count`
   - `cosmica.tier`
6. **App Icon** — `Cosmica/Resources/Assets.xcassets/AppIcon.appiconset` is empty. Drop in a 1024×1024 icon (any icon-generator service will produce all sizes).

## Project layout

```
Cosmica/
├── App/                 # Entry point + AppDelegate
├── Game/
│   ├── Model/           # GameState, Generator, Upgrade, Tier (Codable)
│   ├── Engine/          # GameEngine, CostCurve, OfflineAccrual, PrestigeCalculator
│   └── Content/         # GameContent (seed data: 12 generators, upgrades)
├── Services/            # AdManager, IAPManager, CloudSync, GameCenter, Persistence, Haptics
├── UI/                  # SwiftUI views
└── Resources/           # Info.plist, Assets.xcassets
CosmicaTests/            # XCTest unit tests for math & accrual
```

## Tests

```bash
xcodebuild test -scheme Cosmica -destination "platform=iOS Simulator,name=iPhone 15"
```

The math is pure (`CostCurve`, `PrestigeCalculator`, `OfflineAccrual`) and unit-tested in `CosmicaTests/`.

## License

Proprietary © Centric Fiber.
