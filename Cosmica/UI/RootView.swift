import SwiftUI

struct RootView: View {
    @Binding var offlineSummary: OfflineAccrual.Result?
    @State private var selectedTab: Tab = .observatory

    enum Tab: Hashable { case observatory, upgrades, prestige, shop, settings }

    var body: some View {
        TabView(selection: $selectedTab) {
            ObservatoryView()
                .tabItem { Label("Observatory", systemImage: "scope") }
                .tag(Tab.observatory)

            UpgradesView()
                .tabItem { Label("Upgrades", systemImage: "wand.and.stars") }
                .tag(Tab.upgrades)

            BigBangView()
                .tabItem { Label("Big Bang", systemImage: "burst.fill") }
                .tag(Tab.prestige)

            ShopView()
                .tabItem { Label("Shop", systemImage: "cart") }
                .tag(Tab.shop)

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
                .tag(Tab.settings)
        }
        .tint(.purple)
        .sheet(isPresented: Binding(
            get: { offlineSummary != nil && (offlineSummary?.stardustEarned ?? 0) > 0 },
            set: { if !$0 { offlineSummary = nil } }
        )) {
            if let summary = offlineSummary {
                OfflineWelcomeBackSheet(summary: summary) {
                    offlineSummary = nil
                }
                .presentationDetents([.medium])
            }
        }
    }
}

struct OfflineWelcomeBackSheet: View {
    let summary: OfflineAccrual.Result
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "moon.stars.fill")
                .font(.system(size: 60))
                .foregroundStyle(.purple)
                .padding(.top, 20)

            Text("Welcome back, observer")
                .font(.title2.bold())

            Text("While you were away (\(Formatter.duration(summary.secondsCounted)))")
                .foregroundStyle(.secondary)

            Text("+\(Formatter.short(summary.stardustEarned)) ✦")
                .font(.system(size: 48, weight: .heavy, design: .rounded))
                .foregroundStyle(LinearGradient(colors: [.purple, .blue], startPoint: .leading, endPoint: .trailing))

            if summary.wasCapped {
                Text("Capped at \(Formatter.duration(summary.capUsed)) — watch a rewarded ad in the Shop to extend offline earnings to 24h.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            Spacer()

            Button(action: onDismiss) {
                Text("Continue")
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .background(.purple, in: RoundedRectangle(cornerRadius: 14))
                    .foregroundStyle(.white)
            }
            .padding(.horizontal)
            .padding(.bottom, 24)
        }
    }
}
