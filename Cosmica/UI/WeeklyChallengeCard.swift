import SwiftUI

/// v3.2 — this week's Cosmic Challenge on the Big Bang tab: the goal, progress,
/// the reward, and a Claim button once it's done. See `WeeklyChallenge`.
struct WeeklyChallengeCard: View {
    @Environment(GameEngine.self) private var engine
    @Environment(HapticsManager.self) private var haptics

    @State private var claimedShards: Double?

    private static let star = Color(red: 1.0, green: 0.80, blue: 0.32)

    var body: some View {
        if let challenge = engine.challenge {
            card(challenge)
        }
    }

    private func card(_ c: WeeklyChallenge) -> some View {
        let state = engine.state
        let done = state.challengeCompleted
        let claimed = state.challengeClaimed
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "star.circle.fill").foregroundStyle(Self.star)
                Text("Weekly Challenge").font(.headline).foregroundStyle(.white)
                Spacer()
                TimelineView(.periodic(from: .now, by: 60)) { ctx in
                    let left = max(0, WeeklyChallenge.weekEnd(c.week).timeIntervalSince(ctx.date))
                    Text(claimed ? "Next in \(Formatter.duration(left))" : "Ends in \(Formatter.duration(left))")
                        .font(.caption).foregroundStyle(.secondary).monospacedDigit()
                }
            }

            HStack(alignment: .top, spacing: 12) {
                Image(systemName: c.symbol)
                    .font(.title2)
                    .foregroundStyle(done ? Self.star : .white)
                    .frame(width: 34)
                VStack(alignment: .leading, spacing: 3) {
                    Text(c.title).font(.subheadline.bold()).foregroundStyle(.white)
                    Text(c.detail).font(.caption).foregroundStyle(.secondary)
                }
            }

            if !done {
                ProgressView(value: c.progress(state)).tint(Self.star)
                Text(progressLabel(c, state))
                    .font(.caption).foregroundStyle(.secondary).monospacedDigit()
            }

            if claimed {
                Label(claimedShards.map { "Claimed: ★ +1 and +\(Formatter.short($0)) ◈" } ?? "Claimed. A new challenge starts Monday.",
                      systemImage: "checkmark.seal.fill")
                    .font(.caption.bold()).foregroundStyle(.green)
            } else if done {
                Button {
                    let shards = engine.claimChallenge()
                    if shards > 0 { claimedShards = shards; haptics.upgrade() }
                } label: {
                    Text("Claim ★ Challenge Star + \(Formatter.short(engine.challengeRewardShards)) ◈")
                        .font(.headline)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .foregroundStyle(.black)
                        .background(LinearGradient(colors: [.yellow, .orange], startPoint: .leading, endPoint: .trailing),
                                    in: RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            } else {
                Text("Reward: ★ Challenge Star (+10% earnings, forever) and \(Formatter.short(engine.challengeRewardShards)) ◈")
                    .font(.caption).foregroundStyle(.secondary)
            }

            if state.challengeStars > 0 {
                HStack(spacing: 6) {
                    Text("★ \(state.challengeStars) earned  ·  \(Formatter.multiplier(state.challengeMultiplier)) permanent")
                    if state.challengeStreak > 1 {
                        Text("·  \(state.challengeStreak)-week streak")
                    }
                }
                .font(.caption2).foregroundStyle(Self.star)
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Self.star.opacity(done && !claimed ? 0.8 : 0), lineWidth: 1.5))
        .padding(.horizontal)
    }

    private func progressLabel(_ c: WeeklyChallenge, _ state: GameState) -> String {
        if c.kind == .beatBestRun {
            return "This run: \(Formatter.short(c.doneAmount(state))) of \(Formatter.short(c.goalAmount)) ✦"
        }
        return "\(Formatter.count(min(c.doneAmount(state), c.goalAmount))) of \(Formatter.count(c.goalAmount))"
    }
}
