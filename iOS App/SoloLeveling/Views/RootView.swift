import SwiftUI

/// The main tab shell for the app.
struct RootView: View {
    @EnvironmentObject var store: GameStore

    init() {
        // Style the tab bar to match the System aesthetic.
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(Theme.bgPanel)
        appearance.stackedLayoutAppearance.selected.iconColor = UIColor(Theme.cyan)
        appearance.stackedLayoutAppearance.selected.titleTextAttributes =
            [.foregroundColor: UIColor(Theme.cyan)]
        appearance.stackedLayoutAppearance.normal.iconColor = UIColor(Theme.textDim)
        appearance.stackedLayoutAppearance.normal.titleTextAttributes =
            [.foregroundColor: UIColor(Theme.textDim)]
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    var body: some View {
        TabView {
            DashboardView()
                .tabItem { Label("Status", systemImage: "person.crop.square") }

            QuestsView()
                .tabItem { Label("Quests", systemImage: "checklist") }

            ArmorView()
                .tabItem { Label("Armor", systemImage: "shield.lefthalf.filled") }

            AchievementsView()
                .tabItem { Label("Records", systemImage: "trophy") }

            SyncView()
                .tabItem { Label("Sync", systemImage: "qrcode") }
        }
        .tint(Theme.cyan)
        .overlay(alignment: .top) {
            if store.pendingLevelUps > 0 {
                LevelUpBanner(count: store.pendingLevelUps) {
                    store.clearLevelUps()
                }
            }
        }
    }
}

/// A dismissible "LEVEL UP" banner shown after XP gains that leveled up.
struct LevelUpBanner: View {
    let count: Int
    let dismiss: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "arrow.up.circle.fill")
                .foregroundColor(Theme.goldBright)
            Text(count > 1 ? "LEVEL UP x\(count)" : "LEVEL UP")
                .font(Theme.mono(15, weight: .bold))
                .tracking(2)
                .foregroundColor(Theme.textPrimary)
            Spacer()
            Button(action: dismiss) {
                Image(systemName: "xmark").foregroundColor(Theme.textDim)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Theme.bgElevated)
                .overlay(RoundedRectangle(cornerRadius: 12)
                    .stroke(Theme.gold, lineWidth: 1.5)))
        .shadow(color: Theme.gold.opacity(0.5), radius: 12)
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .transition(.move(edge: .top).combined(with: .opacity))
    }
}
