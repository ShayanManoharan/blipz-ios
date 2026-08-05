import SwiftUI

struct TodayView: View {
    @State private var profileViewModel = ProfileViewModel()
    @State private var imageUrl: URL?
    @State private var displayedTotal: Double = 0
    @State private var todaysBoard: [LeaderboardEntry] = []
    @State private var boardLoaded = false
    @Environment(\.displayScale) private var displayScale
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let games: [BlipzGame] = [.guess, .maths, .trivia]
    private static let maxTotal = 35

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if let profile = profileViewModel.profile {
                        masthead(profile)
                        content(profile)
                    } else if let error = profileViewModel.errorMessage {
                        errorState(error)
                    } else if profileViewModel.isLoading {
                        loadingState
                    }
                }
            }
            .screenBackground()
            .toolbar(.hidden, for: .navigationBar)
            .task {
                await loadImagePreview()
            }
            .onAppear {
                // Fires every time Today becomes the visible top of the stack again —
                // including returning from a just-completed game — so the row that just
                // finished, the up-next card, and the board numbers all catch up promptly
                // instead of waiting for the next cold start.
                Task {
                    await profileViewModel.loadProfile()
                    await loadTodaysBoard()
                }
            }
            .onChange(of: profileViewModel.profile?.totalScore) { _, newTotal in
                guard let newTotal else { return }
                if reduceMotion {
                    displayedTotal = newTotal
                } else {
                    withAnimation(.easeOut(duration: 0.6)) { displayedTotal = newTotal }
                }
            }
        }
    }

    // MARK: - Loading image preview (used only for the small post-completion thumbnail —
    // the daily image is not shown on Today before it's played)

    private func loadImagePreview() async {
        do {
            let content: DailyContent = try await APIClient.shared.get("games/daily-content")
            imageUrl = URL(string: content.imageUrl)
        } catch {
            imageUrl = nil
        }
    }

    private func loadTodaysBoard() async {
        do {
            let response: GlobalLeaderboardResponse = try await APIClient.shared.get("leaderboard/global")
            todaysBoard = response.leaderboard
            boardLoaded = true
        } catch {
            todaysBoard = []
            boardLoaded = false
        }
    }

    // MARK: - Completion / ordering
    //
    // Backed by the backend's explicit maths_completed/guess_completed/trivia_completed
    // fields — a legitimate zero score still reads as completed. Completed games sort
    // above the up-next card; the first not-yet-played game (in fixed guess/maths/trivia
    // order) becomes "up next"; anything after that is dormant.

    private func isCompleted(_ game: BlipzGame, _ profile: UserProfile) -> Bool {
        switch game {
        case .guess: return profile.guessCompleted
        case .maths: return profile.mathsCompleted
        case .trivia: return profile.triviaCompleted
        }
    }

    private func completedGames(_ profile: UserProfile) -> [BlipzGame] {
        Self.games.filter { isCompleted($0, profile) }
    }

    private func upNextGame(_ profile: UserProfile) -> BlipzGame? {
        Self.games.first { !isCompleted($0, profile) }
    }

    private func dormantGames(_ profile: UserProfile) -> [BlipzGame] {
        let upNext = upNextGame(profile)
        return Self.games.filter { !isCompleted($0, profile) && $0 != upNext }
    }

    private func isDayComplete(_ profile: UserProfile) -> Bool {
        upNextGame(profile) == nil
    }

    // MARK: - Per-game copy

    private func title(_ game: BlipzGame) -> String {
        switch game {
        case .guess: return "Guess the prompt"
        case .maths: return "Quick maths"
        case .trivia: return "Trivia"
        }
    }

    private func readySubtitle(_ game: BlipzGame) -> String {
        switch game {
        case .guess: return "Everyone gets the same image"
        case .maths: return "20 problems · timed"
        case .trivia: return "5 questions"
        }
    }

    private func scoreValue(_ game: BlipzGame, _ profile: UserProfile) -> String {
        switch game {
        case .guess: return String(format: "%.1f", profile.guessScore)
        case .maths: return "\(profile.mathsScore)"
        case .trivia: return "\(profile.triviaScore)"
        }
    }

    private func maxScore(_ game: BlipzGame) -> String {
        switch game {
        case .guess: return "10"
        case .maths: return "20"
        case .trivia: return "5"
        }
    }

    private func accessibleName(_ game: BlipzGame) -> String {
        switch game {
        case .guess: return "Guess"
        case .maths: return "Maths"
        case .trivia: return "Trivia"
        }
    }

    @ViewBuilder
    private func destination(for game: BlipzGame) -> some View {
        switch game {
        case .guess: GuessGameView().toolbar(.hidden, for: .tabBar)
        case .maths: MathGameView().toolbar(.hidden, for: .tabBar)
        case .trivia: TriviaGameView().toolbar(.hidden, for: .tabBar)
        }
    }

    // MARK: - Masthead

    private func masthead(_ profile: UserProfile) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text("BLIPZ")
                    .font(.blipzDisplay(size: 17, weight: .bold))
                    .tracking(17 * 0.18)
                Spacer()
                Text("streak \(profile.currentStreak) ›")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("\(profile.currentStreak) day streak")
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)

            Divider()
        }
    }

    // MARK: - Main content

    @ViewBuilder
    private func content(_ profile: UserProfile) -> some View {
        let complete = isDayComplete(profile)

        VStack(alignment: .leading, spacing: 20) {
            if complete {
                completeHeader(profile)
            } else {
                inProgressHeader(profile)
            }

            VStack(alignment: .leading, spacing: 16) {
                HairlineSection(items: completedGames(profile)) { game in
                    completedRow(game, profile: profile, showDenominator: complete)
                }
                if !complete, let upNext = upNextGame(profile) {
                    upNextCard(upNext)
                }
                HairlineSection(items: dormantGames(profile)) { game in
                    dormantRow(game)
                }
            }

            if complete {
                completeExtras(profile)
            } else if completedGames(profile).isEmpty {
                boardTeaser
            } else {
                Text("Finish all three to get your score")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 20)
        .padding(.bottom, 24)
    }

    // MARK: - Headers

    private func inProgressHeader(_ profile: UserProfile) -> some View {
        let doneCount = completedGames(profile).count
        return VStack(alignment: .leading, spacing: 6) {
            Text(dateLine(profile))
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(headline(for: doneCount))
                .font(.system(size: 26, weight: .regular, design: .rounded))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func dateLine(_ profile: UserProfile) -> String {
        let base = Date.now.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
        guard !completedGames(profile).isEmpty else { return base }
        return "\(base) · \(String(format: "%.1f", profile.totalScore)) so far"
    }

    private func headline(for doneCount: Int) -> String {
        switch doneCount {
        case 0: return "Three games.\nOne score."
        case 1: return "Two left."
        default: return "One left."
        }
    }

    private func completeHeader(_ profile: UserProfile) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("\(Date.now.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())) · done")
                .font(.caption)
                .foregroundStyle(.secondary)

            VStack(spacing: 4) {
                Text(displayedTotal, format: .number.precision(.fractionLength(1)))
                    .font(.blipzDisplay(size: 64, weight: .bold))
                    .contentTransition(.numericText(value: displayedTotal))
                Text(scoreCaption)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 22)
            .outlinedContainer(emphasized: true)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Today's score, \(profile.totalScore, specifier: "%.1f") \(scoreCaption)")
        }
    }

    private var scoreCaption: String {
        // A rank is only meaningful when there's someone to be ranked against —
        // "1st of 1" is noise, not information.
        if let rank = rankToday, let players = playersToday, players > 1 {
            return "out of \(Self.maxTotal) · \(ordinal(rank)) of \(players) today"
        }
        return "out of \(Self.maxTotal)"
    }

    private var playersToday: Int? {
        boardLoaded ? todaysBoard.count : nil
    }

    private var rankToday: Int? {
        guard let username = profileViewModel.profile?.username else { return nil }
        return todaysBoard.first(where: { $0.username == username })?.rank
    }

    private func ordinal(_ n: Int) -> String {
        let suffix: String
        switch n % 100 {
        case 11, 12, 13: suffix = "th"
        default:
            switch n % 10 {
            case 1: suffix = "st"
            case 2: suffix = "nd"
            case 3: suffix = "rd"
            default: suffix = "th"
            }
        }
        return "\(n)\(suffix)"
    }

    // MARK: - Rows

    private func completedRow(_ game: BlipzGame, profile: UserProfile, showDenominator: Bool) -> some View {
        let scoreText = showDenominator ? "\(scoreValue(game, profile))/\(maxScore(game))" : scoreValue(game, profile)
        return NavigationLink {
            destination(for: game)
        } label: {
            HStack(spacing: 12) {
                checkmarkBox
                VStack(alignment: .leading, spacing: 2) {
                    Text(title(game))
                        .foregroundStyle(.primary)
                    if !showDenominator {
                        Text("see your result")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Text(scoreText)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.primary)
            }
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(CardPressStyle(reduceMotion: reduceMotion))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(accessibleName(game)), \(scoreValue(game, profile)) out of \(maxScore(game)), complete")
    }

    private var checkmarkBox: some View {
        RoundedRectangle(cornerRadius: 6, style: .continuous)
            .strokeBorder(Color.primary.opacity(0.85), lineWidth: 1.5)
            .frame(width: 24, height: 24)
            .overlay {
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color.primary.opacity(0.85))
            }
    }

    private func upNextCard(_ game: BlipzGame) -> some View {
        NavigationLink {
            destination(for: game)
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                Text("UP NEXT")
                    .font(.caption2.weight(.bold))
                    .tracking(1.2)
                    .foregroundStyle(Theme.accent)
                Text(title(game))
                    .font(.title3.weight(.medium))
                    .foregroundStyle(.primary)
                Text(readySubtitle(game))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text("Play")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Theme.accent, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .padding(.top, 4)
            }
            .padding(16)
            .outlinedContainer(emphasized: true)
        }
        .buttonStyle(CardPressStyle(reduceMotion: reduceMotion))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Up next: \(title(game)). \(readySubtitle(game)). Tap to play.")
    }

    private func dormantRow(_ game: BlipzGame) -> some View {
        NavigationLink {
            destination(for: game)
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title(game))
                        .foregroundStyle(.secondary)
                    Text(readySubtitle(game))
                        .font(.caption)
                        .foregroundStyle(Color(.tertiaryLabel))
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color(.tertiaryLabel))
            }
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(CardPressStyle(reduceMotion: reduceMotion))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title(game)), not yet played. \(readySubtitle(game))")
    }


    // MARK: - Footer (not-complete states)

    private var boardTeaser: some View {
        VStack(spacing: 12) {
            Divider()
            Button {
                Haptics.light()
                TabRouter.shared.selected = .ranks
            } label: {
                HStack {
                    Text("Today's board")
                        .foregroundStyle(.primary)
                    Spacer()
                    if let playersToday {
                        Text("\(playersToday) played ›")
                            .foregroundStyle(.secondary)
                    } else {
                        Text("›")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(playersToday.map { "Today's board, \($0) played today" } ?? "Today's board")
            .accessibilityHint("Opens Ranks")
        }
        .padding(.top, 8)
    }

    // MARK: - Complete-state extras

    private func completeExtras(_ profile: UserProfile) -> some View {
        VStack(spacing: 16) {
            if profile.guessCompleted, let imageUrl {
                NavigationLink {
                    destination(for: .guess)
                } label: {
                    HStack(spacing: 10) {
                        AsyncImage(url: imageUrl) { phase in
                            if case .success(let image) = phase {
                                image.resizable().scaledToFill()
                            } else {
                                Color.secondary.opacity(0.15)
                            }
                        }
                        .frame(width: 40, height: 40)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                        Text("See your guess and score")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color(.tertiaryLabel))
                    }
                }
                .buttonStyle(CardPressStyle(reduceMotion: reduceMotion))
                .accessibilityLabel("See your guess and score for today's Blip")
            }

            shareButton(for: profile)

            Text(nextResetCountdown)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
        }
    }

    private func shareButton(for profile: UserProfile) -> some View {
        let card = ScoreCardRenderer.image(for: profile, displayScale: displayScale)
        return ShareLink(item: card, preview: SharePreview("My Blipz Score", image: card)) {
            Text("Share my result")
        }
        .buttonStyle(PrimaryButtonStyle())
    }

    private var nextResetCountdown: String {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        let now = Date.now
        guard let nextMidnight = cal.nextDate(
            after: now, matching: DateComponents(hour: 0, minute: 0, second: 0), matchingPolicy: .nextTime
        ) else {
            return ""
        }
        let comps = cal.dateComponents([.hour, .minute], from: now, to: nextMidnight)
        return "Next Blip in \(comps.hour ?? 0)h \(comps.minute ?? 0)m"
    }

    // MARK: - Loading / error states

    private func errorState(_ error: String) -> some View {
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
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }

    private var loadingState: some View {
        ProgressView()
            .accessibilityLabel("Loading today's Blipz")
            .frame(maxWidth: .infinity)
            .padding(.top, 60)
    }
}

// MARK: - Press feedback
//
// Scale 0.98 on press, 150ms, no bounce — matches the redesign's motion spec.

private struct CardPressStyle: ButtonStyle {
    var reduceMotion: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

#Preview {
    TodayView()
}
