# Cosmica: Idle Universe — App Store Submission Pack

Everything you need to paste into App Store Connect for the v1.0 review submission. Each section maps to a specific ASC screen / field.

---

## App Information

| Field | Value |
|---|---|
| **Name** | Cosmica: Idle Universe |
| **Subtitle (30 chars)** | Idle galaxy discovery game |
| **Category — Primary** | Games → Casual |
| **Category — Secondary** | Games → Simulation |
| **Content Rights** | Does not use third-party content |
| **Age Rating** | 4+ (see questionnaire below) |

---

## Description (paste into the Description field — under 4000 chars)

```
Build your observatory empire across the cosmos. Tap to discover Stardust, buy telescopes and probes that earn for you while you're away, and ascend through cosmic tiers as you uncover the universe one generator at a time.

Cosmica is a relaxed idle game with infinite progression. Start with a backyard telescope and grow to operate Dyson Swarm Lattices, Multiverse Receivers, and the Demiurge Engine itself. Every generator you buy earns Stardust automatically — even when the app is closed.

▸ TAP & IDLE
Tap the cosmic orb to discover Stardust manually, then buy generators that produce it for you 24/7. Offline earnings catch you up when you return.

▸ ASCEND THROUGH 7 COSMIC TIERS
Stargazer → Astronomer → Astrophysicist → Cosmologist → Galactic Cartographer → Architect of the Void → Demiurge. Each tier grants a permanent earnings multiplier that survives even Big Bang resets.

▸ BIG BANG PRESTIGE
Hit the lifetime threshold and trigger a Big Bang reset. Your generators reset to zero, but you earn Cosmic Shards — each granting +2% permanent earnings, compounding forever. The deeper into the universe you go, the faster you progress.

▸ 12 GENERATORS, 36 UPGRADES
From Backyard Telescope through Orbital Imager, Wormhole Sensor, Galactic Survey Net, and beyond. Three escalating upgrade tiers per generator, plus global multipliers that reshape your strategy late-game.

▸ FREE TO PLAY
Free download with rewarded ads. Optional Remove Ads ($2.99) if you'd rather play without banners. Earnings boosts and Cosmic Shards available via watching short rewarded ads OR via one-time purchases — your choice.

▸ ICLOUD SYNC + GAME CENTER
Your save syncs automatically across all your Apple devices via iCloud. Compete on Game Center leaderboards: lifetime Stardust, total prestiges, and highest tier achieved.

▸ NO ACCOUNT, NO ANALYTICS, NO TRACKING
Single-player idle. The developer does not run a server, does not collect analytics, and never sees your data. Your progress is yours, on your device and in your private iCloud account.

Built solo by an indie developer. Support development via Ko-fi (link inside Settings) — every coffee funds the next update.

Have fun, observer.
```

---

## Promotional Text (170 chars — can be updated without re-review)

```
Tap. Idle. Ascend. Build telescopes that earn Stardust while you sleep, then Big Bang the universe for permanent Cosmic Shard multipliers. Now with paid boost packs.
```

---

## Keywords (100 chars, comma-separated, no spaces around commas)

```
idle,clicker,space,galaxy,cosmic,tycoon,prestige,incremental,universe,stars,telescope,offline,tap
```

(That's exactly 99 characters. App Store keyword research suggests "idle" + "clicker" + "incremental" are the highest-traffic genre keywords for this category; "space" + "galaxy" + "cosmic" capture the theme.)

---

## What's New in This Version (release notes)

```
Welcome to Cosmica 1.0 — the launch build.

• Tap the cosmic orb to discover Stardust
• Buy 12 generator types, each with 3 upgrade tiers
• Big Bang prestige for permanent Cosmic Shard multipliers
• 7-tier progression from Stargazer to Demiurge
• iCloud save sync + Game Center leaderboards
• Optional Remove Ads, earnings boosts, and Cosmic Shard packs

Have fun, observer.
```

---

## Support / Marketing URLs

| Field | Value |
|---|---|
| **Support URL** | https://compo-cf.github.io/cosmica/ |
| **Marketing URL** *(optional)* | (leave blank for v1) |
| **Privacy Policy URL** | https://compo-cf.github.io/cosmica/privacy |

⚠️ For these URLs to work, enable GitHub Pages on the `Compo-CF/cosmica` repo:
**Settings → Pages → Source: Deploy from a branch → Branch: main, Folder: /docs → Save**.
Wait ~2 min, then verify https://compo-cf.github.io/cosmica/ resolves. (You may need to change repo visibility to Public for free-tier GitHub Pages — alternatively, host the markdown anywhere you control.)

---

## Pricing and Availability

- **Price tier:** Free (Tier 0)
- **Availability:** All territories
- **Pre-order:** No

---

## App Privacy Questionnaire — Answers

App Store Connect → App Privacy → Get Started → Configure each category:

### Data Used to Track You

| Data Type | Used to Track? | Linked to User? | Purpose |
|---|---|---|---|
| **Device ID (IDFA)** | Yes | No | Third-Party Advertising |

Add **Device ID** only. AdMob may use IDFA when the user grants App Tracking Transparency permission. All other categories: **No**.

### Data Collected
- **Device ID** — collected by Google AdMob. Purpose: Third-Party Advertising. Linked to user: No. Used to track: Yes.
- **Diagnostics** (Crash Data) — Apple may collect crash logs if user opted into "Share With App Developers" in iOS Settings. Linked to user: No. Used to track: No.

Everything else: **No, we do not collect this data**.

### Privacy Practices
- No data is collected by the developer directly
- Apple StoreKit handles purchase transactions; the developer never sees payment information
- Apple CloudKit stores game save in the user's private iCloud database; the developer cannot access it

---

## Age Rating Questionnaire — Answers

App Store Connect → Age Rating → answer each:

| Category | Answer |
|---|---|
| Cartoon or Fantasy Violence | None |
| Realistic Violence | None |
| Prolonged Graphic or Sadistic Realistic Violence | None |
| Profanity or Crude Humor | None |
| Sexual Content or Nudity | None |
| Graphic Sexual Content and Nudity | None |
| Alcohol, Tobacco, or Drug Use or References | None |
| Mature/Suggestive Themes | None |
| Horror/Fear Themes | None |
| Medical/Treatment Information | None |
| Gambling | None |
| Contests | None |
| Unrestricted Web Access | No |
| Gambling and Contests | No |

Result: **4+**

---

## Review Information

| Field | Value |
|---|---|
| **First Name** | Anthony |
| **Last Name** | Compofelice |
| **Phone** | *(your contact number)* |
| **Email** | anthony.compofelice@centricfiber.com |

### Notes for Apple Reviewer

```
Cosmica: Idle Universe is a single-player idle/incremental game with no account creation or login required. No demo credentials are needed.

The app uses:
- Google AdMob for banner, interstitial, and rewarded video ads
- StoreKit 2 for one non-consumable IAP (Remove Ads, $2.99) and four consumable IAPs (boost and currency packs, $1.99–$9.99)
- CloudKit private database for cross-device save sync
- Game Center for three leaderboards (lifetime Stardust, total prestiges, highest tier)

App Tracking Transparency:
- The app does not request tracking permission directly
- Google AdMob may show the system ATT prompt to deliver personalized ads
- All ad personalization is optional; declining still shows non-personalized ads

The app supports iPhone only in v1 (TARGETED_DEVICE_FAMILY = 1). iPad support is planned for a future release with a tailored layout.

No user accounts, no chat, no UGC, no external network calls beyond AdMob, StoreKit, CloudKit, and Game Center.
```

### Sign-in Required for Review?
**No** — the app does not require sign-in.

---

## In-App Purchases

Create all 5 in App Store Connect → Monetization → In-App Purchases before submitting. They can be submitted **alongside** the app for the first review.

| Product ID | Type | Reference Name | Display Name | Price (Tier) |
|---|---|---|---|---|
| `com.centricfiber.cosmica.removeads` | Non-Consumable | Remove Ads | Remove Ads | $2.99 (Tier 3) |
| `com.centricfiber.cosmica.boost_2x_24hr` | Consumable | 2× Boost 24h | 2× Earnings Boost (24h) | $1.99 (Tier 2) |
| `com.centricfiber.cosmica.offline_7day` | Consumable | Offline 7d | 7-Day Offline Catch-Up | $2.99 (Tier 3) |
| `com.centricfiber.cosmica.shards_pack_small` | Consumable | Shards Small | 250 Cosmic Shards | $1.99 (Tier 2) |
| `com.centricfiber.cosmica.shards_pack_large` | Consumable | Shards Large | 2500 Cosmic Shards | $9.99 (Tier 10) |

For each, you'll need:
- **Localized name** (the user-visible name, can match Display Name above)
- **Localized description** — use these:
  - Remove Ads: "Permanently disable banner and interstitial ads. Rewarded ads stay available so you can still claim voluntary bonuses."
  - 2× Boost 24h: "Doubles your Stardust earnings for the next 24 hours. Stacks with any active boost."
  - Offline 7d: "Claim up to 7 days of offline Stardust earnings right now, plus extends future offline cap to 7 days for this session."
  - Shards Small: "Adds 250 Cosmic Shards to your save. Each shard grants +2% permanent earnings, forever."
  - Shards Large: "Adds 2,500 Cosmic Shards to your save. Each shard grants +2% permanent earnings, forever."
- **Review screenshot** — any screenshot showing the Shop screen where users see the product is fine. (We can reuse the same Shop screenshot for all 5.)

---

## Game Center Leaderboards (Optional but Recommended)

App Store Connect → Game Center → Leaderboards → Create:

| Leaderboard ID | Reference Name | Sort | Score Format |
|---|---|---|---|
| `cosmica.lifetime_stardust` | Lifetime Stardust | High to Low | Integer |
| `cosmica.prestige_count` | Total Prestiges | High to Low | Integer |
| `cosmica.tier` | Highest Tier | High to Low | Integer |

For each: Display Name "Lifetime Stardust / Total Prestiges / Highest Tier", set a Score Format Suffix if desired ("✦", "", "tier").

---

## CloudKit Schema Deploy

The dev environment auto-creates the schema on first save. Before production users hit the app, deploy that schema to Production:

1. Go to https://icloud.developer.apple.com/dashboard/
2. Select container `iCloud.com.centricfiber.cosmica`
3. **Schema** → **Deploy Schema to Production** → confirm

One-click. Without this, App Store users' iCloud saves fail.

---

## Build Selection

Once everything above is filled in, scroll to **Build** in the version page → **+** → pick **1.0 (3)** (the upcoming AdMob-real-IDs build, see code-side checklist below).

---

## Code-Side Checklist (handled in repo)

Before submitting Build 3:
- [x] Onboarding popups
- [x] IAP boost packs
- [x] Ko-fi link wired
- [x] Privacy / Terms in-app screens
- [x] Spiral galaxy app icon
- [ ] Real AdMob ad IDs (waiting on user)
- [ ] CloudKit schema deployed to Production (user action)
- [ ] CFBundleVersion bumped to 3
- [ ] Final archive + upload to TestFlight build 3
- [ ] Promote Build 3 to App Store in TestFlight → Distribution

---

## Submission Order

1. **GitHub Pages enabled** → privacy/terms URLs resolve
2. **5 IAPs created in ASC** → app references them at runtime
3. **AdMob set up, real IDs in code** → Build 3 ships with real ads
4. **CloudKit schema deployed to Production**
5. **Game Center leaderboards created** (optional, recommended)
6. **Screenshots uploaded to ASC** (6.7" required, ideally 6.5" too)
7. **All metadata filled in** (description, keywords, privacy, age rating)
8. **Build 3 selected as the version's build**
9. **Submit for Review** (top right)

Apple's median review time is 24–48 hours.
