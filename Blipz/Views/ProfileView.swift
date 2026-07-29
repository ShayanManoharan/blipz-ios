import SwiftUI

struct ProfileView: View {
    @State private var viewModel = ProfileViewModel()

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                if let profile = viewModel.profile {
                    VStack(spacing: 8) {
                        Image(systemName: "person.crop.circle.fill")
                            .font(.system(size: 56))
                            .foregroundStyle(Theme.accent)
                        Text(profile.username ?? "Guest")
                            .font(.title2.bold())
                    }
                    .frame(maxWidth: .infinity)
                    .cardStyle()

                    HStack(spacing: 16) {
                        StatTile(emoji: "🔥", label: "Current streak", value: "\(profile.currentStreak)")
                        StatTile(emoji: "🏆", label: "Longest streak", value: "\(profile.longestStreak)")
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Today")
                            .font(.headline)
                        ProfileScoreRow(emoji: "🔢", label: "Maths", value: "\(profile.mathsScore)/20")
                        ProfileScoreRow(emoji: "🖼️", label: "Guess", value: String(format: "%.1f/10", profile.guessScore))
                        ProfileScoreRow(emoji: "❓", label: "Trivia", value: "\(profile.triviaScore)/5")
                        Divider()
                        ProfileScoreRow(
                            emoji: "⭐️",
                            label: "Total",
                            value: profile.totalScore.formatted(.number.precision(.fractionLength(1)))
                        )
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .cardStyle()

                    Spacer()
                } else if let error = viewModel.errorMessage {
                    Text(error)
                        .foregroundStyle(.secondary)
                } else if viewModel.isLoading {
                    ProgressView()
                }
            }
            .padding()
            .screenBackground()
            .navigationTitle("Profile")
            .task {
                await viewModel.loadProfile()
            }
        }
    }
}

private struct StatTile: View {
    let emoji: String
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 6) {
            Text(emoji).font(.title2)
            Text(value)
                .font(.title2.bold())
                .foregroundStyle(Theme.accent)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .cardStyle()
    }
}

private struct ProfileScoreRow: View {
    let emoji: String
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(emoji)
            Text(label)
            Spacer()
            Text(value).bold()
        }
    }
}

#Preview {
    ProfileView()
}
