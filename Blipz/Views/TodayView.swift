import SwiftUI

struct TodayView: View {
    @State private var profileViewModel = ProfileViewModel()
    @State private var imageUrl: URL?
    @State private var displayedTotal: Double = 0
    @State private var todaysBoard: [LeaderboardEntry] = []
    @State private var boardLoaded = false
    @Environment(\.displayScale) private var displayScale
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private static let games: [BlipzGame] = [.guess, .maths, .trivia]
    // total_score is always today's — and today is always on/after the normalized-
    // scoring cutover (see backend app/scoring.py) — so this is never ambiguous here,
    // unlike History's multi-day window (see YouView's legacy-scoring handling).
    private static let maxTotal = 100

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

    // Maths is a stopwatch game — every completed run is 20/20 by construction (you
    // can't advance past a problem without answering it correctly), so the count isn't
    // meaningful. Elapsed time is what actually varies, so it takes the "score" slot
    // here once that metadata exists; older completed rows without it fall back to the
    // plain completion count rather than showing nothing.
    private func mathsRowText(_ profile: UserProfile) -> String {
        guard let elapsed = profile.mathsElapsedSeconds else { return "done" }
        let total = Int(elapsed.rounded())
        return String(format: "%d:%02d", total / 60, total % 60)
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
                HStack(spacing: 5) {
                    Image(systemName: "flame.fill")
                        .font(.caption)
                        .foregroundStyle(Theme.streak)
                    Text("\(profile.currentStreak) day streak")
                        .font(.caption.weight(.medium))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(Theme.surface, in: Capsule())
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(profile.currentStreak) day streak")
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 12)

            Divider()
        }
    }

    // MARK: - Main content

    @ViewBuilder
    private func content(_ profile: UserProfile) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            dailyHeader(profile)
            gameList(profile)
            dailyProgress(profile)

            if let next = upNextGame(profile) {
                nextGameButton(next, continuing: !completedGames(profile).isEmpty)
                Text("Finish all three games to lock in today's score")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            } else {
                completeExtras(profile)
            }

            boardTeaser
        }
        .padding(.horizontal, 18)
        .padding(.top, 18)
        .padding(.bottom, 24)
    }

    // MARK: - Direction A daily hierarchy

    private func dailyHeader(_ profile: UserProfile) -> some View {
        let doneCount = completedGames(profile).count
        return VStack(alignment: .leading, spacing: 6) {
            Text(Date.now.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(headline(for: doneCount))
                .font(.system(size: 26, weight: .bold))
            Text("3 games. 1 daily score. 100 points.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private func gameList(_ profile: UserProfile) -> some View {
        VStack(spacing: 0) {
            ForEach(Self.games, id: \.self) { game in
                compactGameRow(game, profile: profile)
                if game != Self.games.last {
                    Divider().padding(.leading, 74)
                }
            }
        }
        .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Theme.hairline.opacity(0.7), lineWidth: 0.5)
        )
    }

    private func compactGameRow(_ game: BlipzGame, profile: UserProfile) -> some View {
        let completed = isCompleted(game, profile)
        return NavigationLink {
            destination(for: game)
        } label: {
            Group {
                if dynamicTypeSize.isAccessibilitySize {
                    accessibleGameRowContent(game, profile: profile, completed: completed)
                } else {
                    standardGameRowContent(game, profile: profile, completed: completed)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .contentShape(Rectangle())
        }
        .buttonStyle(CardPressStyle(reduceMotion: reduceMotion))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            completed
                ? completedRowAccessibilityLabel(game, profile: profile)
                : "\(title(game)), not yet played. \(readySubtitle(game))"
        )
    }

    private func standardGameRowContent(_ game: BlipzGame, profile: UserProfile, completed: Bool) -> some View {
        HStack(spacing: 12) {
            completionIndicator(completed)
            gameEmblem(game)
            gameRowLabels(game, profile: profile, completed: completed, limitSubtitle: true)
            Spacer(minLength: 8)
            gameRowTrailing(game, profile: profile, completed: completed)
        }
    }

    private func accessibleGameRowContent(_ game: BlipzGame, profile: UserProfile, completed: Bool) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                completionIndicator(completed)
                gameEmblem(game)
                gameRowLabels(game, profile: profile, completed: completed, limitSubtitle: false)
                Spacer(minLength: 4)
                if !completed {
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color(.tertiaryLabel))
                        .padding(.top, 8)
                }
            }
            if completed {
                Text(completedTrailingValue(game, profile: profile))
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
    }

    private func gameRowLabels(
        _ game: BlipzGame,
        profile: UserProfile,
        completed: Bool,
        limitSubtitle: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title(game))
                .font(.body.weight(.semibold))
                .foregroundStyle(.primary)
            Text(completed ? completedSubtitle(game, profile: profile) : readySubtitle(game))
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(limitSubtitle ? 1 : nil)
        }
    }

    @ViewBuilder
    private func gameRowTrailing(_ game: BlipzGame, profile: UserProfile, completed: Bool) -> some View {
        if completed {
            Text(completedTrailingValue(game, profile: profile))
                .font(.body.weight(.semibold))
                .foregroundStyle(.primary)
        } else {
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color(.tertiaryLabel))
        }
    }

    private func completionIndicator(_ completed: Bool) -> some View {
        Circle()
            .fill(completed ? Theme.accent : Color.clear)
            .overlay(
                Circle().strokeBorder(completed ? Theme.accent : Color.secondary.opacity(0.55), lineWidth: 1.5)
            )
            .frame(width: 20, height: 20)
            .overlay {
                if completed {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
            .accessibilityHidden(true)
    }

    private func gameEmblem(_ game: BlipzGame) -> some View {
        let symbol: String = switch game {
        case .guess: "photo"
        case .maths: "plus.forwardslash.minus"
        case .trivia: "questionmark"
        }
        return RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(Theme.accentWash)
            .frame(width: 42, height: 42)
            .overlay(
                Image(systemName: symbol)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Theme.accent)
            )
            .accessibilityHidden(true)
    }

    private func completedSubtitle(_ game: BlipzGame, profile: UserProfile) -> String {
        switch game {
        case .guess: return "Your score"
        case .maths: return profile.mathsElapsedSeconds == nil ? "Completed" : "Elapsed time"
        case .trivia: return "Correct answers"
        }
    }

    private func completedTrailingValue(_ game: BlipzGame, profile: UserProfile) -> String {
        switch game {
        case .guess: return "\(scoreValue(game, profile)) /10"
        case .maths: return mathsRowText(profile)
        case .trivia: return "\(scoreValue(game, profile)) /5"
        }
    }

    private func dailyProgress(_ profile: UserProfile) -> some View {
        let done = completedGames(profile).count
        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Your daily progress")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text("\(done) / 3 games")
                    .font(.caption.weight(.medium))
            }

            ProgressView(value: Double(done), total: 3)
                .tint(Color.white.opacity(0.9))

            HStack(alignment: .lastTextBaseline, spacing: 4) {
                Text("Today's score")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.75))
                Spacer()
                Text(profile.totalScore, format: .number.precision(.fractionLength(1)))
                    .font(.blipzDisplay(size: 28, weight: .bold))
                Text("/100")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.75))
            }
        }
        .foregroundStyle(.white)
        .padding(16)
        .background(Theme.accentPressed, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(done) of 3 games complete. Today's score \(profile.totalScore, specifier: "%.1f") out of 100")
    }

    private func nextGameButton(_ game: BlipzGame, continuing: Bool) -> some View {
        NavigationLink {
            destination(for: game)
        } label: {
            Text("\(continuing ? "Continue" : "Play"): \(title(game))")
        }
        .buttonStyle(PrimaryButtonStyle())
        .simultaneousGesture(TapGesture().onEnded { Haptics.light() })
    }

    // MARK: - Headers

    private func inProgressHeader(_ profile: UserProfile) -> some View {
        let doneCount = completedGames(profile).count
        return VStack(alignment: .leading, spacing: 6) {
            Text(dateLine(profile))
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(headline(for: doneCount))
                .font(.system(size: 26, weight: .regular))
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
        case 0: return "Let's keep it going."
        case 1: return "Two left."
        case 2: return "One left."
        default: return "All done for today."
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
        let scoreText: String
        if game == .maths {
            scoreText = mathsRowText(profile)
        } else {
            scoreText = showDenominator ? "\(scoreValue(game, profile))/\(maxScore(game))" : scoreValue(game, profile)
        }
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
        .accessibilityLabel(completedRowAccessibilityLabel(game, profile: profile))
    }

    private func completedRowAccessibilityLabel(_ game: BlipzGame, profile: UserProfile) -> String {
        guard game == .maths else {
            return "\(accessibleName(game)), \(scoreValue(game, profile)) out of \(maxScore(game)), complete"
        }
        if let elapsed = profile.mathsElapsedSeconds {
            let total = Int(elapsed.rounded())
            return "Maths, solved in \(total / 60) minutes \(total % 60) seconds, complete"
        }
        return "Maths, complete"
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
