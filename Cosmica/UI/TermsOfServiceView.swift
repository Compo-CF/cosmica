import SwiftUI

struct TermsOfServiceView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Terms of Service")
                    .font(.largeTitle.bold())
                Text("Last updated: June 25, 2026")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                section(title: "Agreement", body: """
                By installing or using Cosmica ("the app"), you agree to these Terms of Service. If you don't agree, please uninstall the app. Cosmica is provided by Anthony Compofelice ("the developer"), an independent developer.
                """)

                section(title: "License", body: """
                The developer grants you a personal, non-exclusive, non-transferable, revocable license to install and use the app on devices you own or control, subject to these Terms and Apple's App Store Terms of Use.
                """)

                section(title: "In-App Purchases", body: """
                Cosmica offers consumable and non-consumable in-app purchases:
                • Remove Ads (non-consumable) — disables banner and interstitial ads permanently.
                • Earnings Boost (consumable) — temporarily doubles Stardust earnings.
                • Offline Catch-Up (consumable) — extends offline earning cap and grants immediate Stardust.
                • Cosmic Shards Pack (consumable) — adds Cosmic Shards to your save.

                All purchases are processed by Apple. The developer does not handle your payment information. Purchases are governed by Apple's standard refund policies — the developer cannot issue refunds directly.

                Consumable purchases are applied immediately to your current save and do not transfer or restore between devices independently of CloudKit sync. Non-consumable purchases (Remove Ads) can be restored on any device signed into the same Apple ID via "Restore Purchases" in the Shop or Settings screen.
                """)

                section(title: "Virtual currencies", body: """
                Stardust (✦) and Cosmic Shards (◈) are in-game virtual currencies. They have no real-world monetary value, cannot be redeemed for cash, and cannot be transferred between accounts. The developer may modify game balance — including currency rates, generator costs, and prestige thresholds — at any time. Lost or "missing" virtual currency from balance changes is not refundable.
                """)

                section(title: "Cloud saves", body: """
                Game progress syncs through your private iCloud account when available. The developer cannot access, modify, or recover your saves. If iCloud sync conflicts arise, the save with greater lifetime Stardust takes precedence.
                """)

                section(title: "Advertising", body: """
                Unless you purchase Remove Ads, the app displays banner and interstitial ads served by Google AdMob, plus rewarded ads you can choose to watch for in-game bonuses. Rewarded ads remain available even with Remove Ads purchased — they provide voluntary benefits.
                """)

                section(title: "Acceptable use", body: """
                You agree not to:
                • Modify, decompile, reverse-engineer, or distribute the app outside the App Store.
                • Exploit bugs to gain currency or progression you didn't legitimately earn (we may reset progress on saves found to be tampered with).
                • Use the app in any way that violates Apple's App Store Guidelines or applicable law.
                """)

                section(title: "Disclaimer of warranties", body: """
                Cosmica is provided "AS IS" without warranty of any kind. The developer does not guarantee uninterrupted operation, bug-free behavior, or that the app will remain available indefinitely. The developer reserves the right to discontinue the app at any time.
                """)

                section(title: "Limitation of liability", body: """
                To the maximum extent permitted by law, the developer is not liable for any indirect, incidental, special, or consequential damages arising from your use of the app, including lost time, lost progress, or lost purchases. Total liability is limited to the amount you paid for in-app purchases in the past 30 days.
                """)

                section(title: "Changes to these terms", body: """
                These Terms may be updated. Material changes will be reflected here with an updated "Last updated" date. Continued use of the app after a change constitutes acceptance.
                """)

                section(title: "Governing law", body: """
                These Terms are governed by the laws of the State of Texas, United States, without regard to conflict-of-law principles.
                """)

                section(title: "Contact", body: """
                Questions about these Terms: contact Anthony Compofelice via the support link in the Shop screen.
                """)

                Spacer().frame(height: 24)
            }
            .padding()
            .foregroundStyle(.primary)
        }
        .navigationTitle("Terms of Service")
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
