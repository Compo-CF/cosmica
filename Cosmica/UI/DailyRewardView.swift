import SwiftUI

/// The daily-login reward sheet. Shows the streak and the pending reward; claiming
/// grants it and dismisses (availability flips false, closing the sheet).
struct DailyRewardView: View {
    @Environment(GameEngine.self) var engine
    @Environment(HapticsManager.self) var haptics
    let onClaim: () -> Void

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

            Button {
                _ = engine.claimDaily()
                haptics.dailyClaim()
                onClaim()
            } label: {
                Text("Claim")
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .background(.cyan, in: RoundedRectangle(cornerRadius: 14))
                    .foregroundStyle(.black)
            }
            .padding(.horizontal)
            .padding(.bottom, 24)
        }
    }
}
