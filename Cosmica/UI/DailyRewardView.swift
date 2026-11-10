import SwiftUI

/// The daily-login reward sheet. Shows the streak and the pending reward; claiming
/// grants it and dismisses (availability flips false, closing the sheet).
struct DailyRewardView: View {
    @Environment(GameEngine.self) var engine
    @Environment(HapticsManager.self) var haptics
    @Environment(ReviewPrompter.self) var reviewPrompter
    @Environment(AdManager.self) var ads
    let onClaim: () -> Void
    @State private var adBusy = false

    var body: some View {
        let reward = engine.previewDailyReward()
        return VStack(spacing: 18) {
            Image(systemName: "gift.fill")
                .font(.system(size: 56))
                .foregroundStyle(.cyan)
                .padding(.top, 24)

            Text("Daily Signal")
                .font(.title2.bold())

            Text("Day \(reward.day) of 7  ·  \(reward.streak)-day streak")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            // 7-day dot track.
            HStack(spacing: 8) {
                ForEach(1...7, id: \.self) { d in
                    Circle()
                        .fill(d <= reward.day ? Color.cyan : Color.white.opacity(0.15))
                        .frame(width: 12, height: 12)
                }
            }

            Text(reward.summary)
                .font(.system(size: 26, weight: .heavy, design: .rounded))
                .foregroundStyle(LinearGradient(colors: [.cyan, .purple], startPoint: .leading, endPoint: .trailing))
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Spacer()

            // v3.4.1 — optional ×2 for a rewarded ad. The plain Claim stays the
            // big button: the ad is an offer, never the way through.
            Button {
                adBusy = true
                var rewarded = false
                // Claim once the ad has closed: claiming dismisses this sheet,
                // which would take the still-showing ad down with it.
                ads.watch(placement: "daily_double", onReward: {
                    rewarded = true
                }, onDismiss: {
                    adBusy = false
                    if rewarded { claim(multiplier: 2) }
                })
            } label: {
                HStack {
                    Image(systemName: "play.rectangle.fill")
                    Text(ads.rewardedReady ? "Watch Ad · Claim ×2" : "Ad loading…")
                }
                .font(.subheadline.bold())
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(Color.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
                .foregroundStyle(.primary)
            }
            .disabled(adBusy || !ads.rewardedReady)
            .padding(.horizontal)

            Button {
                claim(multiplier: 1)
            } label: {
                Text("Claim")
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .background(.cyan, in: RoundedRectangle(cornerRadius: 14))
                    .foregroundStyle(.black)
            }
            .disabled(adBusy)
            .padding(.horizontal)
            .padding(.bottom, 24)
        }
    }

    private func claim(multiplier: Double) {
        guard engine.dailyRewardAvailable else { onClaim(); return }
        _ = engine.claimDaily(multiplier: multiplier)
        haptics.dailyClaim()
        // v4.0 — the 7-day-streak rating ask is gone (ReviewPrompter: big moments only).
        onClaim()
    }
}
