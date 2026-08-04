import SwiftUI

struct TodayView: View {
    @State private var profileViewModel = ProfileViewModel()
    @State private var imageUrl: URL?
    @State private var displayedTotal: Double = 0
    @Environment(\.displayScale) private var displayScale
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
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
                        VStack(spacing: 12) {
                            Text(error)
                                .foregroundStyle(Theme.error)
                                .multilineTextAlignment(.center)
                            Button("Try Again") {
                                Task { await profileViewModel.loadProfile() }
                            }
                            .buttonStyle(.bordered)
                            .tint(Theme.accent)
                        }
                        .padding(.top, 60)
                    } else if profileViewModel.isLoading {
                        ProgressView()
                            .accessibilityLabel("Loading today's Blipz")
                            .padding(.top, 60)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 20)
            }
            .screenBackground()
            .toolbar(.hidden, for: .navigationBar)
            .task {
                await loadImagePreview()
            }
            .onAppear {
                // Fires every time Today becomes the visible top of the stack again —
                // including returning from a just-completed game — not just on first
                // launch, so the Ready → Completed transition actually happens promptly
                // instead of waiting for the next cold start.
                Task { await profileViewModel.loadProfile() }
            }
            .onChange(of: profileViewModel.profile?.totalScore) { _, newTotal in
                guard let newTotal else { return }
                if reduceMotion {
                    displayedTotal = newTotal
                } else {
                    withAnimation(.easeOut(duration: 0.9)) { displayedTotal = newTotal }
                }
            }
        }
    }

    // MARK: - Completion derivation
    //
    // Backed by the backend's explicit maths_completed/guess_completed/trivia_completed
    // fields (see PRODUCTION_AUDIT.md B2 and its fix) — no more score-based heuristics.
    // A legitimate zero score now correctly still reads as completed.

    private var isMathsCompleted: Bool { profileViewModel.profile?.mathsCompleted ?? false }
    private var isGuessCompleted: Bool { profileViewModel.profile?.guessCompleted ?? false }
    private var isTriviaCompleted: Bool { profileViewModel.profile?.triviaCompleted ?? false }

    private var completedCount: Int {
        [isGuessCompleted, isMathsCompleted, isTriviaCompleted].filter { $0 }.count
    }

    private func loadImagePreview() async {
        do {
            let content: DailyContent = try await APIClient.shared.get("games/daily-content")
            let url = URL(string: content.imageUrl)
            // A tasteful one-time reveal when today's image first arrives, instead of
            // it just popping in — see heroImage's matching .transition. Gated by
            // Reduce Motion like every other animation in this view.
            if reduceMotion {
                imageUrl = url
            } else {
                withAnimation(.easeOut(duration: 0.5)) { imageUrl = url }
            }
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
        .animation(reduceMotion ? nil : .spring(response: 0.5, dampingFraction: 0.75), value: isGuessCompleted)
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
        .animation(reduceMotion ? nil : .spring(response: 0.5, dampingFraction: 0.75), value: isMathsCompleted)
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
        .animation(reduceMotion ? nil : .spring(response: 0.5, dampingFraction: 0.75), value: isTriviaCompleted)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Daily Trivia, \(state == .completed ? "completed" : "ready")")
    }

    // Total/share card evolves with state instead of showing a flat "0.0" before
    // anything has been played. The number itself counts up (displayedTotal, driven by
    // the onChange in `body`) instead of just appearing — a small but real "less passive
    // score presentation" touch, matching the same pattern GuessGameView already uses
    // for its own result reveal.
    @ViewBuilder
    private func totalSection(_ profile: UserProfile) -> some View {
        switch completedCount {
        case 0:
            VStack(spacing: 4) {
                Text("Today's Blipz is ready")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Play all 3 to complete today's set")
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
                    Text(displayedTotal, format: .number.precision(.fractionLength(1)))
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.accent)
                        .contentTransition(.numericText(value: displayedTotal))
                }
                Text("\(3 - completedCount) to go")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                shareLink(for: profile, style: .bordered)
            }
            .frame(maxWidth: .infinity)
            .padding(14)
            .background(Theme.accent.opacity(0.08), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .accessibilityElement(children: .combine)

        default:
            VStack(spacing: 10) {
                Label("Daily Blipz complete", systemImage: "checkmark.seal.fill")
                    .font(.headline)
                    .foregroundStyle(Theme.success)
                Text(displayedTotal, format: .number.precision(.fractionLength(1)))
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.accent)
                    .contentTransition(.numericText(value: displayedTotal))
                Text("Come back tomorrow for a new Blip")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                shareLink(for: profile, style: .prominent)
            }
            .frame(maxWidth: .infinity)
            .padding(16)
            .background(Theme.success.opacity(0.1), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .accessibilityElement(children: .combine)
            .transition(.scale(scale: 0.94).combined(with: .opacity))
            .animation(reduceMotion ? nil : .spring(response: 0.5, dampingFraction: 0.7), value: completedCount)
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

    // A modest, bounded list rather than open-ended math — only real streak values the
    // backend already reports, no invented "percentile"/"rank"-style data.
    private static let milestones: Set<Int> = [3, 7, 14, 21, 30, 50, 75, 100, 150, 200, 365]
    private var isMilestone: Bool { Self.milestones.contains(streak) }

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
                VStack(alignment: .trailing, spacing: 2) {
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill")
                            .font(isMilestone ? .title3 : .body)
                            .foregroundStyle(Theme.streak)
                        Text("\(streak)")
                            .font(isMilestone ? .title3.weight(.bold) : .headline)
                    }
                    if isMilestone {
                        Text("Streak milestone!")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(Theme.streak)
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(isMilestone ? "\(streak) day streak, a milestone" : "\(streak) day streak")
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
    // Distinguishes "still loading, be curious" from "this genuinely failed" — see
    // heroImage's .failure phase — so a real error never gets dressed up as mystery.
    var isError: Bool = false
    @State private var animate = false

    var body: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(
                LinearGradient(
                    colors: isError
                        ? [Color.secondary.opacity(0.15), Color.secondary.opacity(0.1)]
                        : [Theme.accent.opacity(0.18), TodayAccent.maths.opacity(0.14), Theme.accent.opacity(0.18)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
            )
            .overlay(shimmerSweep)
            .overlay(captionOverlay)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .onAppear {
                guard !reduceMotion, !isError else { return }
                withAnimation(.linear(duration: 1.3).repeatForever(autoreverses: false)) {
                    animate = true
                }
            }
    }

    private var shimmerSweep: some View {
        LinearGradient(
            colors: [.clear, (isError ? Color.secondary : Theme.accent).opacity(0.2), .clear],
            startPoint: .leading, endPoint: .trailing
        )
        .rotationEffect(.degrees(12))
        .offset(x: reduceMotion || isError ? 0 : (animate ? 240 : -240))
    }

    @ViewBuilder
    private var captionOverlay: some View {
        if isError {
            VStack(spacing: 4) {
                Image(systemName: "photo.badge.exclamationmark")
                    .font(.caption)
                Text("Couldn't load image")
                    .font(.caption2.weight(.medium))
            }
            .foregroundStyle(.secondary)
        } else {
            // A large, faint "?" turns the wait itself into part of the mystery —
            // "what did AI create today?" — rather than looking like a stalled spinner.
            ZStack {
                Text("?")
                    .font(.system(size: 44, weight: .black, design: .rounded))
                    .foregroundStyle(Theme.accent.opacity(0.12))

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
                    // Checkmark, not just color, carries "completed" — see Part 4's
                    // accessibility pass: state should never rely on color alone.
                    Label("Completed", systemImage: "checkmark.circle.fill")
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
                            .transition(reduceMotion ? .identity : .opacity.combined(with: .scale(scale: 0.97)))
                    case .failure:
                        ShimmerPlaceholder(reduceMotion: reduceMotion, isError: true)
                    default:
                        ShimmerPlaceholder(reduceMotion: reduceMotion, caption: "Generating today's Blip…")
                    }
                }
            } else {
                ShimmerPlaceholder(reduceMotion: reduceMotion, caption: "Generating today's Blip…")
            }
        }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.5), value: imageUrl)
        .frame(height: 132)
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            LinearGradient(colors: [.clear, .black.opacity(0.22)], startPoint: .top, endPoint: .bottom)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        )
        .overlay(alignment: .topLeading) {
            // A small "event" marker on the image itself — this is *today's* Blip, a
            // one-off, not generic artwork — reinforced without adding new copy weight
            // elsewhere on the card.
            Text("TODAY'S BLIP")
                .font(.caption2.weight(.bold))
                .tracking(0.5)
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.black.opacity(0.32), in: Capsule())
                .padding(8)
        }
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

            // Checkmark, not just color, carries "completed" — state should never rely
            // on color alone (Part 4's accessibility pass).
            HStack(spacing: 3) {
                if state == .completed {
                    Image(systemName: "checkmark")
                        .font(.caption2.weight(.bold))
                }
                Text(state == .completed ? "Completed" : "Play")
                    .font(.caption2.weight(.bold))
            }
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
