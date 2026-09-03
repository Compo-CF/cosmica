import SwiftUI

/// Read-only board of every shipping Achievement. Ordering matches
/// `AchievementCatalog.all`. Progress bars and unlock state are derived from the
/// live `GameState`; no local caching so re-opening the screen always reflects
/// what the engine has just observed.
struct AchievementsView: View {
    @Environment(GameEngine.self) private var engine

    var body: some View {
        ZStack {
            background
            ScrollView {
                VStack(spacing: 14) {
                    headerCard
                    ForEach(AchievementCatalog.all) { a in
                        AchievementRow(
                            achievement: a,
                            state: engine.state,
                            unlocked: engine.state.unlockedAchievementIds.contains(a.id)
                        )
                        .padding(.horizontal)
                    }
                }
                .padding(.top, 6)
                .padding(.bottom, 24)
            }
        }
        .navigationTitle("Achievements")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.black, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }

    private var background: some View {
        ZStack {
            Color.black
            RadialGradient(
                colors: [Color.orange.opacity(0.20), .clear],
                center: .top, startRadius: 5, endRadius: 380
            )
        }
        .ignoresSafeArea()
    }

    private var headerCard: some View {
        let total = AchievementCatalog.all.count
        let unlocked = engine.state.unlockedAchievementIds.count
        let mult = AchievementCatalog.multiplier(unlocked: engine.state.unlockedAchievementIds)
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "rosette")
                    .font(.title2)
                    .foregroundStyle(.orange)
                    .frame(width: 40)
                VStack(alignment: .leading) {
                    Text("\(unlocked) of \(total) unlocked")
                        .font(.headline).foregroundStyle(.white)
                    Text("Every achievement adds a small permanent bonus.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Text("×\(String(format: "%.3f", mult))")
                    .font(.title3.bold())
                    .foregroundStyle(.orange)
                    .monospacedDigit()
            }
            ProgressView(value: total > 0 ? Double(unlocked) / Double(total) : 0)
                .tint(.orange)
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal)
    }
}

private struct AchievementRow: View {
    let achievement: Achievement
    let state: GameState
    let unlocked: Bool

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(tierGradient)
                    .frame(width: 46, height: 46)
                    .opacity(unlocked ? 1 : 0.35)
                Image(systemName: unlocked ? achievement.symbol : "lock.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(unlocked ? .white : .secondary)
            }
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(achievement.title)
                        .font(.subheadline.bold())
                        .foregroundStyle(unlocked ? .white : .secondary)
                    Text(achievement.tier.label)
                        .font(.caption2.bold())
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(tierColor.opacity(0.25), in: Capsule())
                        .foregroundStyle(tierColor)
                }
                Text(achievement.detail)
                    .font(.caption).foregroundStyle(.secondary)
                if !unlocked {
                    ProgressView(value: achievement.goal.progress(state: state))
                        .tint(tierColor)
                        .padding(.top, 2)
                }
            }
            Spacer(minLength: 0)
            Text(unlocked ? "+\(bonusPct)%" : "")
                .font(.caption2.bold())
                .foregroundStyle(tierColor)
                .monospacedDigit()
        }
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private var bonusPct: String {
        String(format: "%.1f", achievement.tier.bonus * 100)
    }

    private var tierColor: Color {
        switch achievement.tier {
        case .bronze:   return Color(red: 0.80, green: 0.55, blue: 0.30)
        case .silver:   return Color(red: 0.85, green: 0.87, blue: 0.92)
        case .gold:     return Color(red: 1.00, green: 0.82, blue: 0.30)
        case .platinum: return Color(red: 0.75, green: 0.90, blue: 1.00)
        }
    }

    private var tierGradient: LinearGradient {
        LinearGradient(
            colors: [tierColor.opacity(0.9), tierColor.opacity(0.5)],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
    }
}
