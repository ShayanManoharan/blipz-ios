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

                        DailyProgressTracker(
                            guessCompleted: isGuessCompleted,
                            mathsCompleted: isMathsCompleted,
                            triviaCompleted: isTriviaCompleted
                        )

                        heroWidget(profile)
                        supportingWidgets(profile)
                        totalSection(profile)
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
                ? "Daily AI Guess, completed, score \(String(format: "%.1f", profile.guessScore)) out of 10"
                : "Daily AI Guess, ready, tap to make your guess"
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
                game: .maths,
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
                game: .trivia,
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

    // Total/share card evolves with state instead of showing a flat "0.0" before
    // anything has been played.
    @ViewBuilder
    private func totalSection(_ profile: UserProfile) -> some View {
        switch completedCount {
        case 0:
            VStack(spacing: 4) {
                Text("Today's score")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Play a game to get started")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Theme.accent)
            }
            .frame(maxWidth: .infinity)
            .padding(14)
            .background(Theme.accent.opacity(0.08), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .accessibilityElement(children: .combine)

        case 1, 2:
            VStack(spacing: 12) {
                VStack(spacing: 4) {
                    Text("Today's score")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(profile.totalScore, format: .number.precision(.fractionLength(1)))
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.accent)
                }
                shareLink(for: profile, style: .bordered)
            }
            .frame(maxWidth: .infinity)
            .padding(14)
            .background(Theme.accent.opacity(0.08), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .accessibilityElement(children: .combine)

        default:
            VStack(spacing: 10) {
                Text("Daily Blipz complete")
                    .font(.headline)
                    .foregroundStyle(Theme.success)
                Text(profile.totalScore, format: .number.precision(.fractionLength(1)))
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.accent)
                shareLink(for: profile, style: .prominent)
            }
            .frame(maxWidth: .infinity)
            .padding(16)
            .background(Theme.success.opacity(0.1), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .accessibilityElement(children: .combine)
        }
    }

    private enum ShareLinkStyle { case bordered, prominent }

    private func shareLink(for profile: UserProfile, style: ShareLinkStyle) -> some View {
        let card = ScoreCardRenderer.image(for: profile, displayScale: displayScale)
        return Group {
            switch style {
            case .bordered:
                ShareLink(item: card, preview: SharePreview("My Blipz Score", image: card)) {
                    Label("Share my results", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(.bordered)
                .tint(Theme.accent)
            case .prominent:
                ShareLink(item: card, preview: SharePreview("My Blipz Score", image: card)) {
                    Label("Share my results", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(PrimaryButtonStyle())
            }
        }
    }
}

// MARK: - Card state

private enum DailyGameCardState {
    case ready
    case completed
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
                Text("Today")
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

// MARK: - Daily progress tracker
//
// Deliberately not a segmented-control look-alike (no shared pill container) — three
// separate icon nodes joined by a track line, so it reads as a completion tracker,
// not a tappable filter/picker.

private struct DailyProgressTracker: View {
    let guessCompleted: Bool
    let mathsCompleted: Bool
    let triviaCompleted: Bool

    private var completedCount: Int {
        [guessCompleted, mathsCompleted, triviaCompleted].filter { $0 }.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(completedCount) of 3 complete")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            HStack(spacing: 0) {
                node(game: .guess, completed: guessCompleted)
                track(active: guessCompleted)
                node(game: .maths, completed: mathsCompleted)
                track(active: mathsCompleted)
                node(game: .trivia, completed: triviaCompleted)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func node(game: BlipzGame, completed: Bool) -> some View {
        BlipzGameEmblem(game: game, size: 26, isCompleted: completed)
            .animation(.easeOut(duration: 0.3), value: completed)
    }

    private func track(active: Bool) -> some View {
        Rectangle()
            .fill(active ? Theme.success.opacity(0.4) : Color.secondary.opacity(0.15))
            .frame(height: 2)
            .frame(maxWidth: .infinity)
            .animation(.easeOut(duration: 0.3), value: active)
    }
}

// MARK: - Shimmer placeholder

private struct ShimmerPlaceholder: View {
    let reduceMotion: Bool
    var caption: String?
    @State private var animate = false

    var body: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [Theme.accent.opacity(0.18), TodayAccent.maths.opacity(0.14), Theme.accent.opacity(0.18)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
            )
            .overlay(shimmerSweep)
            .overlay(captionOverlay)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.linear(duration: 1.3).repeatForever(autoreverses: false)) {
                    animate = true
                }
            }
    }

    private var shimmerSweep: some View {
        LinearGradient(
            colors: [.clear, Theme.accent.opacity(0.25), .clear],
            startPoint: .leading, endPoint: .trailing
        )
        .rotationEffect(.degrees(12))
        .offset(x: reduceMotion ? 0 : (animate ? 240 : -240))
    }

    @ViewBuilder
    private var captionOverlay: some View {
        if let caption {
            VStack(spacing: 4) {
                Image(systemName: "sparkles")
                    .font(.caption)
                Text(caption)
                    .font(.caption2.weight(.medium))
            }
            .foregroundStyle(Theme.accent.opacity(0.75))
        }
    }
}

// MARK: - Hero widget (AI Prompt Guess)

private struct HeroGameWidget: View {
    let state: DailyGameCardState
    let imageUrl: URL?
    let score: Double
    let reduceMotion: Bool

    private var tint: Color { state == .completed ? Theme.success : TodayAccent.guess }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                BlipzGameEmblem(game: .guess, size: 40, isCompleted: state == .completed)
                    .animation(reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.6), value: state)

                VStack(alignment: .leading, spacing: 2) {
                    Text("DAILY AI GUESS")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(TodayAccent.guess)
                        .tracking(1)
                    Text("What did AI create?")
                        .font(.headline)
                    Text("Everyone sees the same image")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            heroImage

            HStack {
                if state == .completed {
                    Text(String(format: "%.1f / 10", score))
                        .font(.headline)
                        .foregroundStyle(TodayAccent.guess)
                    Text("Completed")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.success)
                } else {
                    Text("Make your guess")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(TodayAccent.guess)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(tint.opacity(0.6))
            }
        }
        .padding(14)
        .background(tint.opacity(state == .completed ? 0.12 : 0.10), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(tint.opacity(state == .completed ? 0.4 : 0.35), lineWidth: 1.5)
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
                    case .failure:
                        ShimmerPlaceholder(reduceMotion: reduceMotion, caption: nil)
                    default:
                        ShimmerPlaceholder(reduceMotion: reduceMotion, caption: "Generating today's Blip…")
                    }
                }
            } else {
                ShimmerPlaceholder(reduceMotion: reduceMotion, caption: "Generating today's Blip…")
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
    let game: BlipzGame
    let title: String
    let readyDescriptor: String
    let completedValue: String
    let state: DailyGameCardState

    private var tint: Color { state == .completed ? Theme.success : game.accent }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            BlipzGameEmblem(game: game, size: 36, isCompleted: state == .completed)

            Text(title)
                .font(.subheadline.weight(.semibold))

            Text(state == .completed ? completedValue : readyDescriptor)
                .font(.caption2)
                .foregroundStyle(.secondary)

            Text(state == .completed ? "Completed" : "Play")
                .font(.caption2.weight(.bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Capsule().fill(tint))
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tint.opacity(state == .completed ? 0.10 : 0.08), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(tint.opacity(state == .completed ? 0.4 : 0.35), lineWidth: 1.5)
        )
    }
}

#Preview {
    TodayView()
}
