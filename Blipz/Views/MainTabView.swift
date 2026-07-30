import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            TodayView()
                .tabItem { Label("Today", systemImage: "house.fill") }

            LeaderboardView()
                .tabItem { Label("Leaderboard", systemImage: "trophy") }

            FriendsView()
                .tabItem { Label("Friends", systemImage: "person.2.fill") }

            ProfileView()
                .tabItem { Label("Profile", systemImage: "person.crop.circle") }
        }
        .tint(Theme.accent)
    }
}

#Preview {
    MainTabView()
}
