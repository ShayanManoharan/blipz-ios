import SwiftUI

struct MainTabView: View {
    @State private var router = TabRouter.shared

    var body: some View {
        // Three tabs per the 2a redesign — Friends is folded into Ranks as a
        // segment (see the Ranks screen), not its own tab.
        TabView(selection: $router.selected) {
            TodayView()
                .tabItem { Label("Today", systemImage: "house") }
                .tag(AppTab.today)

            RanksView()
                .tabItem { Label("Ranks", systemImage: "list.number") }
                .tag(AppTab.ranks)

            YouView()
                .tabItem { Label("You", systemImage: "person") }
                .tag(AppTab.you)
        }
        .tint(Theme.accent)
    }
}

#Preview {
    MainTabView()
}
