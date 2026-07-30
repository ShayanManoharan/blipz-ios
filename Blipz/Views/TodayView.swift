import SwiftUI

struct TodayView: View {
    @State private var profileViewModel = ProfileViewModel()
    @State private var imageUrl: URL?
    @Environment(\.displayScale) private var displayScale
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @ScaledMetric(relativeTo: .title) private var headerFontSize: CGFloat = 28

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    header

                    if profileViewModel.profile != nil {
                        progressSection
                        heroCard
                        supportingCards
                        totalCard
                        shareSection
                    } else if let error = profileViewModel.errorMessage {
                        Text(error)
                            .foregroundStyle(.secondary)
                    } else if profileViewModel.isLoading {
                        ProgressView()
                    }
                }
                .padding()
            }
            .screenBackground()
            .navigationTitle("Today")
            .task {
                await profileViewModel.loadProfile()
                await loadImagePreview()
            }
        }
    }

    // MARK: - Data

    private var profile: UserProfile? { profileViewModel.profile }

    private var mathsCompleted: Bool { (profile?.mathsScore ?? 0) == 20 }
    private var guessCompleted: Bool { (profile?.guessScore ?? 0) > 0 }
    private var triviaCompleted: Bool { (profile?.triviaScore ?? 0) > 0 }

    private var completedCount: Int {
        [mathsCompleted, guessCompleted, triviaCompleted].filter { $0 }.count
    }

    private func loadImagePreview() async {
        do {
            let content: DailyContent = try await APIClient.shared.get("games/daily-content")
            imageUrl = URL(string: content.imageUrl)
        } catch {
            imageUrl = nil
        }
    }

    // MARK: - Sections

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Today's Blipz")
                    .font(.system(size: headerFontSize, weight: .bold, design: .rounded))
                Text(Date.now.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if let streak = profile?.currentStreak, streak > 0 {
                VStack(spacing: 2) {
                    Image(systemName: "flame.fill")
                        .foregroundStyle(Theme.streak)
                    Text("\(streak)")
                        .font(.headline)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(streak) day streak")
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var progressSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(completedCount) of 3 completed")
                .font(.subheadline.weight(.semibold))
            ProgressView(value: Double(completedCount), total: 3)
                .tint(Theme.accent)
                .animation(.easeOut(duration: 0.3), value: completedCount)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var heroCard: some View {
        NavigationLink {
            GuessGameView()
                .toolbar(.hidden, for: .tabBar)
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Today's Blip")
                            .font(.title2.bold())
                        Text("Everyone sees the same image today")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    StatusBadge(isCompleted: guessCompleted)
                }

                heroImage

                HStack {
                    if guessCompleted, let profile {
                        Text("Score: \(String(format: "%.1f", profile.guessScore))/10")
                            .font(.headline)
                            .foregroundStyle(Theme.accent)
                    } else {
                        Spacer(minLength: 0)
                    }
                    Spacer()
                    CTALabel(isCompleted: guessCompleted)
                }
            }
            .cardStyle()
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(guessAccessibilityLabel)
    }

    private var guessAccessibilityLabel: String {
        guessCompleted
            ? "Today's Blip, completed, score \(String(format: "%.1f", profile?.guessScore ?? 0)) out of 10"
            : "Today's Blip, not played, tap to play"
    }

    @ViewBuilder
    private var heroImage: some View {
        if let imageUrl {
            AsyncImage(url: imageUrl) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(height: 180)
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .shadow(color: Theme.accent.opacity(0.2), radius: 14, y: 8)
                case .failure:
                    placeholderImage
                default:
                    placeholderImage.overlay(ProgressView())
                }
            }
            .accessibilityHidden(true)
        } else {
            placeholderImage.overlay(ProgressView())
                .accessibilityHidden(true)
        }
    }

    private var placeholderImage: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(Theme.accent.opacity(0.1))
            .frame(height: 180)
    }

    private var supportingCards: some View {
        Group {
            if horizontalSizeClass == .regular {
                HStack(spacing: 16) { mathsCard; triviaCard }
            } else {
                VStack(spacing: 16) { mathsCard; triviaCard }
            }
        }
    }

    private var mathsCard: some View {
        NavigationLink {
            MathGameView()
                .toolbar(.hidden, for: .tabBar)
        } label: {
            GameCard(
                icon: "number",
                title: "Quick Maths",
                subtitle: "20 problems, as fast as you can",
                progressText: "\(profile?.mathsScore ?? 0)/20",
                isCompleted: mathsCompleted
            )
        }
        .buttonStyle(.plain)
    }

    private var triviaCard: some View {
        NavigationLink {
            TriviaGameView()
                .toolbar(.hidden, for: .tabBar)
        } label: {
            GameCard(
                icon: "questionmark.circle",
                title: "Daily Trivia",
                subtitle: "Five questions, once a day",
                progressText: "\(profile?.triviaScore ?? 0)/5",
                isCompleted: triviaCompleted
            )
        }
        .buttonStyle(.plain)
    }

    private var totalCard: some View {
        VStack(spacing: 6) {
            Text("Today's Total")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text((profile?.totalScore ?? 0), format: .number.precision(.fractionLength(1)))
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.accent)
        }
        .frame(maxWidth: .infinity)
        .cardStyle()
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var shareSection: some View {
        if completedCount > 0, let profile {
            let card = ScoreCardRenderer.image(for: profile, displayScale: displayScale)

            if completedCount == 3 {
                VStack(spacing: 12) {
                    Text("All three completed!")
                        .font(.headline)
                        .foregroundStyle(Theme.success)
                    ShareLink(item: card, preview: SharePreview("My Blipz Score", image: card)) {
                        Label("Share my results", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(PrimaryButtonStyle())
                }
                .frame(maxWidth: .infinity)
                .cardStyle()
            } else {
                ShareLink(item: card, preview: SharePreview("My Blipz Score", image: card)) {
                    Label("Share my results", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(.bordered)
                .tint(Theme.accent)
            }
        }
    }
}

private struct StatusBadge: View {
    let isCompleted: Bool

    var body: some View {
        Text(isCompleted ? "Completed" : "Not played")
            .font(.caption2.weight(.semibold))
            .foregroundStyle(isCompleted ? Theme.success : .secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule().fill((isCompleted ? Theme.success : Color.secondary).opacity(0.15))
            )
    }
}

private struct CTALabel: View {
    let isCompleted: Bool

    var body: some View {
        Label(isCompleted ? "View Result" : "Play", systemImage: "chevron.right")
            .labelStyle(.titleAndIcon)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Theme.accent)
    }
}

private struct GameCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let progressText: String
    let isCompleted: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(Theme.accent)
                Spacer()
                StatusBadge(isCompleted: isCompleted)
            }

            Text(title)
                .font(.headline)
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                Text(progressText)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.accent)
                Spacer()
                CTALabel(isCompleted: isCompleted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title), \(isCompleted ? "completed" : "not played")")
    }
}

#Preview {
    TodayView()
}
