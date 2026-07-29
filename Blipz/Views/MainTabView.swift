import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            MathGameView()
                .tabItem { Label("Maths", systemImage: "number") }

            GuessGameView()
                .tabItem { Label("Guess", systemImage: "photo") }

            TriviaGameView()
                .tabItem { Label("Trivia", systemImage: "questionmark.circle") }

            LeaderboardView()
                .tabItem { Label("Leaderboard", systemImage: "trophy") }
        }
        .tint(Theme.accent)
    }
}

#Preview {
    MainTabView()
}
