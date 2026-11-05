import SwiftUI

struct PrivacyPolicyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Privacy Policy")
                    .font(.largeTitle.bold())
                Text("Last updated: November 5, 2026")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                section(title: "TL;DR", body: """
                Cosmica is a single-player idle game. Anthony Compofelice (the developer) does not operate a server and does not collect any personal information. The only thing the developer sees is an anonymous daily count of Shop activity, described below, which you can switch off. Your game progress lives on your device and, if you're signed into iCloud, in your private iCloud account. Three third-party services are involved — Apple, Google, and StoreKit — each governed by their own privacy policies linked below.
                """)

                section(title: "What the developer collects", body: """
                Anonymous Shop counts, and nothing else. Each day Cosmica counts how many times the Shop was opened, how often each item was shown, how often each buy or watch-ad button was tapped, and how many purchases and ad rewards completed. If you're signed into iCloud, that day's counts are stored as one record in Cosmica's iCloud (CloudKit) public database, under a random name that changes every day, so one day can't be connected to another or to you. The record holds no name, Apple ID, device identifier, location, game progress or payment details. The developer uses the totals to see which items players find useful.

                To stop it, turn off Settings → Legal → "Share anonymous Shop stats". That also deletes the counts kept on your device.

                There is no analytics SDK and no crash reporter operated by the developer.
                """)

                section(title: "Your game progress", body: """
                Cosmica saves your game state (currency totals, generators owned, upgrades purchased, prestige count, last-seen timestamp, settings) to a JSON file on your device. If you are signed into iCloud, that save is also stored in your private CloudKit database so it syncs to your other Apple devices signed into the same Apple ID. Only you can read or write that record. The developer cannot.
                """)

                section(title: "Advertising — Google AdMob", body: """
                When ads are enabled (you have not purchased Remove Ads), Cosmica displays advertisements via Google AdMob. Google may collect your device's advertising identifier (IDFA), IP address, and other technical information to serve relevant ads and measure performance.

                You can opt out of personalized ads at any time:
                • Settings → Privacy & Security → Tracking — disable "Allow Apps to Request to Track" or revoke this app's permission specifically.
                • Settings → Privacy & Security → Apple Advertising — disable Personalized Ads.
                • In the EEA, UK and Switzerland, Cosmica shows Google's consent form before any ads load. Change your choices any time with "Privacy choices" in Cosmica's Settings.

                Google AdMob's privacy policy: https://policies.google.com/privacy
                """)

                section(title: "Purchases — Apple StoreKit", body: """
                In-app purchases (Remove Ads, boost packs, shard packs) are processed by Apple's StoreKit and the App Store. The developer never sees your payment information. Apple shares only the receipt and a verification flag with this app, used to unlock the purchased content.

                Apple's privacy policy: https://www.apple.com/legal/privacy/
                """)

                section(title: "Leaderboards — Apple Game Center", body: """
                If you sign into Game Center, your lifetime Stardust earned, total prestiges, and current tier may be submitted to Game Center leaderboards. Your nickname is visible to other players. You can sign out, hide your scores, or remove your participation any time in Settings → Game Center.

                Apple Game Center privacy controls: https://support.apple.com/en-us/HT207082
                """)

                section(title: "Children's privacy (COPPA)", body: """
                Cosmica does not knowingly collect personal information from children under 13. The app contains in-app purchases and third-party advertising. Parents should enable Ask to Buy in Family Sharing and Restrict Ad Tracking on their child's device.
                """)

                section(title: "Your rights", body: """
                The developer holds no personal data: the anonymous Shop counts can't be traced to you, so there is nothing to access, correct, or delete on the developer's side. Switching the Shop stats off stops them and clears what's on your device. For data held by Google or Apple, exercise rights through their respective privacy controls linked above.
                """)

                section(title: "Changes to this policy", body: """
                If this policy materially changes, the updated text will appear here and the "Last updated" date will move forward. Continued use of the app after a change indicates acceptance.
                """)

                section(title: "Contact", body: """
                Questions, concerns, or feedback: open an issue at the Cosmica project page, or contact Anthony Compofelice directly via the support link in the Shop screen.
                """)

                Spacer().frame(height: 24)
            }
            .padding()
            .foregroundStyle(.primary)
        }
        .navigationTitle("Privacy Policy")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func section(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.title3.bold())
                .padding(.top, 8)
            Text(body)
                .font(.body)
        }
    }
}
