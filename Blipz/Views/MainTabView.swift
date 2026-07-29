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

            LeaderboardComingSoonView()
                .tabItem { Label("Leaderboard", systemImage: "trophy") }
        }
    }
}

private struct LeaderboardComingSoonView: View {
    var body: some View {
        VStack {
            Text("Leaderboard coming soon")
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    MainTabView()
}
