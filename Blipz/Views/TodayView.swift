import SwiftUI

struct TodayView: View {
    @State private var profileViewModel = ProfileViewModel()
    @State private var imageUrl: URL?
    @Environment(\.displayScale) private var displayScale
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    if let profile = profileViewModel.profile {
                        TodayHeader(streak: profile.currentStreak)

                        DailyProgressSegments(
                            guessCompleted: isGuessCompleted,
                            mathsCompleted: isMathsCompleted,
                            triviaCompleted: isTriviaCompleted
                        )

                        heroWidget(profile)
                        supportingWidgets(profile)
                        totalCard(profile)
                        shareSection(profile)
                    } else if let error = profileViewModel.errorMessage {
                        Text(error)
                            .foregroundStyle(.secondary)
                    } else if profileViewModel.isLoading {
                        ProgressView()
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 20)
            }
            .screenBackground()
            .toolbar(.hidden, for: .navigationBar)
            .task {
                await profileViewModel.loadProfile()
                await loadImagePreview()
            }
        }
    }

    // MARK: - Completion derivation
    //
    // Centralized here so this is the one place to update once the backend adds
    // explicit maths_completed/guess_completed/trivia_completed fields. Until then,
    // there is no persisted "in progress" state anywhere, so this screen only ever
    // shows Ready or Completed.

    private var isMathsCompleted: Bool {
        (profileViewModel.profile?.mathsScore ?? 0) == 20
    }

    // NOTE: inferred from score > 0 because the backend has no explicit "played"
    // flag yet. A legitimate score of exactly 0.0 will incorrectly read as "not
    // played." Replace with a real `guess_completed` field when the backend adds one.
    private var isGuessCompleted: Bool {
        (profileViewModel.profile?.guessScore ?? 0) > 0
    }

    // NOTE: same limitation as Guess above — replace with `trivia_completed` once
    // the backend exposes it.
    private var isTriviaCompleted: Bool {
        (profileViewModel.profile?.triviaScore ?? 0) > 0
    }

    private var completedCount: Int {
        [isGuessCompleted, isMathsCompleted, isTriviaCompleted].filter { $0 }.count
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

    private func heroWidget(_ profile: UserProfile) -> some View {
        let state: DailyGameCardState = isGuessCompleted ? .completed : .ready

        return NavigationLink {
            GuessGameView()
                .toolbar(.hidden, for: .tabBar)
        } label: {
            HeroGameWidget(state: state, imageUrl: imageUrl, score: profile.guessScore, reduceMotion: reduceMotion)
        }
        .buttonStyle(CardPressStyle(reduceMotion: reduceMotion))
        .simultaneousGesture(TapGesture().onEnded { Haptics.light() })
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            state == .completed
                ? "Today's Blip, completed, score \(String(format: "%.1f", profile.guessScore)) out of 10"
                : "Today's Blip, ready, tap to make your guess"
        )
    }

    private func supportingWidgets(_ profile: UserProfile) -> some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(spacing: 12) {
                    mathsWidget(profile)
                    triviaWidget(profile)
                }
            } else {
                HStack(spacing: 12) {
                    mathsWidget(profile)
                    triviaWidget(profile)
                }
            }
        }
    }

    private func mathsWidget(_ profile: UserProfile) -> some View {
        let state: DailyGameCardState = isMathsCompleted ? .completed : .ready

        return NavigationLink {
            MathGameView()
                .toolbar(.hidden, for: .tabBar)
        } label: {
            CompactGameWidget(
                icon: "number",
                title: "Quick Maths",
                readyDescriptor: "20 problems",
                completedValue: "\(profile.mathsScore)/20",
                state: state
            )
        }
        .buttonStyle(CardPressStyle(reduceMotion: reduceMotion))
        .simultaneousGesture(TapGesture().onEnded { Haptics.light() })
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Quick Maths, \(state == .completed ? "completed" : "ready")")
    }

    private func triviaWidget(_ profile: UserProfile) -> some View {
        let state: DailyGameCardState = isTriviaCompleted ? .completed : .ready

        return NavigationLink {
            TriviaGameView()
                .toolbar(.hidden, for: .tabBar)
        } label: {
            CompactGameWidget(
                icon: "questionmark.circle",
                title: "Daily Trivia",
                readyDescriptor: "5 questions",
                completedValue: "\(profile.triviaScore)/5",
                state: state
            )
        }
        .buttonStyle(CardPressStyle(reduceMotion: reduceMotion))
        .simultaneousGesture(TapGesture().onEnded { Haptics.light() })
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Daily Trivia, \(state == .completed ? "completed" : "ready")")
    }

    private func totalCard(_ profile: UserProfile) -> some View {
        VStack(spacing: 4) {
            Text("Today's Total")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(profile.totalScore, format: .number.precision(.fractionLength(1)))
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.accent)
        }
        .frame(maxWidth: .infinity)
        .padding(14)
        .background(Theme.accent.opacity(0.08), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func shareSection(_ profile: UserProfile) -> some View {
        if completedCount > 0 {
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
                .padding(16)
                .background(Theme.success.opacity(0.1), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
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

// MARK: - Card state

private enum DailyGameCardState {
    case ready
    case completed

    var backgroundColor: Color {
        switch self {
        case .ready: return Theme.accent.opacity(0.10)
        case .completed: return Theme.success.opacity(0.12)
        }
    }

    var borderColor: Color {
        switch self {
        case .ready: return Theme.accent.opacity(0.35)
        case .completed: return Theme.success.opacity(0.4)
        }
    }
}

private struct CardPressStyle: ButtonStyle {
    var reduceMotion: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

// MARK: - Header

private struct TodayHeader: View {
    let streak: Int
    @ScaledMetric(relativeTo: .title2) private var titleFontSize: CGFloat = 22

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Today's Blipz")
                    .font(.system(size: titleFontSize, weight: .bold, design: .rounded))
                Text(Date.now.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if streak > 0 {
                HStack(spacing: 4) {
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
}

// MARK: - Progress segments

private struct DailyProgressSegments: View {
    let guessCompleted: Bool
    let mathsCompleted: Bool
    let triviaCompleted: Bool

    private var completedCount: Int {
        [guessCompleted, mathsCompleted, triviaCompleted].filter { $0 }.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("\(completedCount) of 3 complete")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            HStack(spacing: 6) {
                segment(label: "Guess", completed: guessCompleted)
                segment(label: "Maths", completed: mathsCompleted)
                segment(label: "Trivia", completed: triviaCompleted)
            }
        }
    }

    private func segment(label: String, completed: Bool) -> some View {
        HStack(spacing: 3) {
            if completed {
                Image(systemName: "checkmark")
                    .font(.system(size: 9, weight: .bold))
            }
            Text(label)
                .font(.caption2.weight(.semibold))
        }
        .foregroundStyle(completed ? Theme.success : Theme.accent.opacity(0.65))
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity)
        .background(
            Capsule().fill(completed ? Theme.success.opacity(0.15) : Theme.accent.opacity(0.1))
        )
        .overlay(
            Capsule().strokeBorder(completed ? Theme.success.opacity(0.4) : Theme.accent.opacity(0.25), lineWidth: 1)
        )
        .animation(.easeOut(duration: 0.3), value: completed)
    }
}

// MARK: - Completion checkmark

private struct CompletionCheckmark: View {
    var body: some View {
        Image(systemName: "checkmark.circle.fill")
            .foregroundStyle(Theme.success)
            .transition(.scale.combined(with: .opacity))
    }
}

// MARK: - Shimmer placeholder

private struct ShimmerPlaceholder: View {
    let reduceMotion: Bool
    @State private var animate = false

    var body: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(Theme.accent.opacity(0.12))
            .overlay(
                LinearGradient(
                    colors: [.clear, Theme.accent.opacity(0.22), .clear],
                    startPoint: .leading, endPoint: .trailing
                )
                .rotationEffect(.degrees(12))
                .offset(x: reduceMotion ? 0 : (animate ? 240 : -240))
            )
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.linear(duration: 1.3).repeatForever(autoreverses: false)) {
                    animate = true
                }
            }
    }
}

// MARK: - Hero widget (AI Prompt Guess)

private struct HeroGameWidget: View {
    let state: DailyGameCardState
    let imageUrl: URL?
    let score: Double
    let reduceMotion: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("TODAY'S BLIP")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(Theme.accent)
                        .tracking(1)
                    Text("What did AI create?")
                        .font(.headline)
                    Text("Everyone sees the same image")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if state == .completed {
                    CompletionCheckmark()
                        .font(.title3)
                        .animation(reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.6), value: state)
                }
            }

            heroImage

            HStack {
                if state == .completed {
                    Text(String(format: "%.1f / 10", score))
                        .font(.headline)
                        .foregroundStyle(Theme.accent)
                    Text("Completed")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.success)
                } else {
                    Text("Make your guess")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.accent)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Theme.accent.opacity(0.6))
            }
        }
        .padding(14)
        .background(state.backgroundColor, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(state.borderColor, lineWidth: 1.5)
        )
    }

    @ViewBuilder
    private var heroImage: some View {
        Group {
            if let imageUrl {
                AsyncImage(url: imageUrl) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    default:
                        ShimmerPlaceholder(reduceMotion: reduceMotion)
                    }
                }
            } else {
                ShimmerPlaceholder(reduceMotion: reduceMotion)
            }
        }
        .frame(height: 100)
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            LinearGradient(colors: [.clear, .black.opacity(0.18)], startPoint: .top, endPoint: .bottom)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        )
        .accessibilityHidden(true)
    }
}

// MARK: - Compact widget (Maths / Trivia)

private struct CompactGameWidget: View {
    let icon: String
    let title: String
    let readyDescriptor: String
    let completedValue: String
    let state: DailyGameCardState

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(Theme.accent)
                Spacer()
                if state == .completed {
                    CompletionCheckmark()
                        .font(.subheadline)
                } else {
                    Image(systemName: "chevron.right")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(Theme.accent.opacity(0.5))
                }
            }

            Text(title)
                .font(.subheadline.weight(.semibold))

            Text(state == .completed ? "\(completedValue) · Completed" : "\(readyDescriptor) · Ready")
                .font(.caption2)
                .foregroundStyle(state == .completed ? Theme.success : .secondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(state.backgroundColor, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(state.borderColor, lineWidth: 1.5)
        )
    }
}

#Preview {
    TodayView()
}
