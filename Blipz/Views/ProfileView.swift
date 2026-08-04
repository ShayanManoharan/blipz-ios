import SwiftUI

struct ProfileView: View {
    @State private var viewModel = ProfileViewModel()
    @Environment(\.displayScale) private var displayScale
    @ScaledMetric(relativeTo: .largeTitle) private var totalFontSize: CGFloat = 40

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                if let profile = viewModel.profile {
                    heroCard(profile)

                    HStack(spacing: 16) {
                        StatTile(icon: "flame.fill", tint: Theme.streak, label: "Current streak", value: "\(profile.currentStreak)")
                        StatTile(icon: "trophy.fill", tint: Theme.gold, label: "Longest streak", value: "\(profile.longestStreak)")
                    }

                    todayCard(profile)
                    totalCard(profile)

                    if profile.totalScore > 0 {
                        let card = ScoreCardRenderer.image(for: profile, displayScale: displayScale)
                        ShareLink(item: card, preview: SharePreview("My Blipz Score", image: card)) {
                            Label("Share my results", systemImage: "square.and.arrow.up")
                        }
                        .buttonStyle(.bordered)
                        .tint(Theme.accent)
                    }

                    Spacer()
                } else if let error = viewModel.errorMessage {
                    Text(error)
                        .foregroundStyle(Theme.error)
                } else if viewModel.isLoading {
                    ProgressView()
                        .accessibilityLabel("Loading profile")
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

    private func heroCard(_ profile: UserProfile) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "person.crop.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(Theme.accent)
            Text(profile.username ?? "Guest")
                .font(.title2.bold())
        }
        .frame(maxWidth: .infinity)
        .cardStyle()
    }

    private func todayCard(_ profile: UserProfile) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Today")
                .font(.headline)

            GameProgressRow(
                icon: "number", label: "Maths",
                score: "\(profile.mathsScore)/20",
                progress: Double(profile.mathsScore) / 20,
                isComplete: profile.mathsCompleted
            )
            GameProgressRow(
                icon: "photo", label: "Guess",
                score: String(format: "%.1f/10", profile.guessScore),
                progress: profile.guessScore / 10,
                isComplete: profile.guessCompleted
            )
            GameProgressRow(
                icon: "questionmark.circle", label: "Trivia",
                score: "\(profile.triviaScore)/5",
                progress: Double(profile.triviaScore) / 5,
                isComplete: profile.triviaCompleted
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    private func totalCard(_ profile: UserProfile) -> some View {
        VStack(spacing: 6) {
            Text("Today's Total")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(profile.totalScore, format: .number.precision(.fractionLength(1)))
                .font(.system(size: totalFontSize, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.accent)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .cardStyle()
    }
}

private struct StatTile: View {
    let icon: String
    let tint: Color
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(tint)
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
        .accessibilityElement(children: .combine)
    }
}

private struct GameProgressRow: View {
    let icon: String
    let label: String
    let score: String
    let progress: Double
    let isComplete: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(Theme.accent)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 4) {
                Text(label)
                    .font(.subheadline.weight(.medium))
                ProgressView(value: min(max(progress, 0), 1))
                    .tint(Theme.accent)
            }

            Spacer()

            if isComplete {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Theme.success)
            }

            Text(score)
                .bold()
                .foregroundStyle(Theme.accent)
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    ProfileView()
}
