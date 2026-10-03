import SwiftUI

struct TodayView: View {
    @State private var profileViewModel = ProfileViewModel()
    @State private var content: DailyContent?
    @State private var contentUnavailable = false
    @State private var displayedTotal = 0.0
    @State private var router = TabRouter.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        NavigationStack(path: $router.todayPath) {
            ScrollView {
                VStack(alignment: .leading, spacing: 11) {
                    masthead
                    editorialHeader
                    if let profile = profileViewModel.profile {
                        guessHero(profile)
                        compactGame(.maths, profile: profile)
                        compactGame(.trivia, profile: profile)
                        dailyProgress(profile)
                        nextAction(profile)
                        boardLink
                    } else if let error = profileViewModel.errorMessage {
                        ContentUnavailableView {
                            Label("A little connection trouble", systemImage: "wifi.exclamationmark")
                        } description: { Text(error) } actions: {
                            Button("Try again") { Task { await refresh() } }
                                .buttonStyle(.bordered)
                        }
                    } else {
                        ProgressView("Loading your daily Blip…")
                            .frame(maxWidth: .infinity).padding(.vertical, 48)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 48)
            }
            .screenBackground()
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: BlipzGame.self) { game in
                switch game {
                case .guess: GuessGameView().toolbar(.hidden, for: .tabBar)
                case .maths: MathGameView().toolbar(.hidden, for: .tabBar)
                case .trivia: TriviaGameView().toolbar(.hidden, for: .tabBar)
                }
            }
            .refreshable { await refresh() }
            .onAppear { Task { await refresh() } }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { Task { await refresh() } }
            }
            .onChange(of: profileViewModel.profile?.totalScore) { _, score in
                withAnimation(reduceMotion ? nil : .easeOut(duration: 0.45)) {
                    displayedTotal = score ?? 0
                }
            }
        }
    }

    private func refresh() async {
        await profileViewModel.loadProfile()
        do {
            let daily: DailyContent = try await APIClient.shared.get("games/daily-content")
            // Never carry yesterday's image across a UTC rollover.
            content = daily.date == BlipzDay.key() ? daily : nil
            contentUnavailable = content == nil
        } catch {
            content = nil
            contentUnavailable = true
        }
    }

    private var masthead: some View {
        ViewThatFits(in: .horizontal) {
            HStack {
                BlipzWordmark()
                Spacer(minLength: 8)
                if let profile = profileViewModel.profile { BlipzStreakPill(streak: profile.currentStreak) }
            }
            VStack(alignment: .leading, spacing: 10) {
                BlipzWordmark()
                if let profile = profileViewModel.profile { BlipzStreakPill(streak: profile.currentStreak) }
            }
        }
    }

    private var editorialHeader: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("\(BlipzDay.label().uppercased()) · DAILY BLIP")
                .font(.caption2.weight(.semibold)).tracking(0.6).foregroundStyle(.secondary)
            Text(isComplete ? "Brilliant curiosity!" : "A little more curious.")
                .font(.blipzEditorial).foregroundStyle(Theme.brandInk)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            Text("Three games. One daily score. A fresh perspective.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private var isComplete: Bool {
        guard let profile = profileViewModel.profile else { return false }
        return BlipzGame.orderedDaily.allSatisfy { profile.isCompleted($0) }
    }

    private var imageURL: URL? { content.flatMap { URL(string: $0.imageUrl) } }

    private func guessHero(_ profile: UserProfile) -> some View {
        gameLink(.guess, profile: profile) {
            VStack(alignment: .leading, spacing: 0) {
                ZStack(alignment: .bottomLeading) {
                    if let imageURL {
                        AsyncImage(url: imageURL) { phase in
                            if let image = phase.image {
                                image.resizable().scaledToFill()
                            } else {
                                heroPlaceholder(loading: phase.error == nil)
                            }
                        }
                        .frame(height: 160).clipped()
                        LinearGradient(colors: [.clear, .black.opacity(0.65)], startPoint: .center, endPoint: .bottom)
                        Text("What was the\nAI thinking?")
                            .font(.system(.title, design: .serif)).foregroundStyle(.white)
                            .padding(16)
                    } else {
                        heroPlaceholder(loading: !contentUnavailable)
                    }
                    VStack {
                        HStack {
                            Label("A LITTLE IMAGINATION", systemImage: "sparkle")
                                .font(.caption2.weight(.semibold))
                                .padding(.horizontal, 9).padding(.vertical, 7)
                                .background(Theme.cardBackground, in: Capsule())
                                .foregroundStyle(Theme.brandInk)
                            Spacer()
                            Text("01 / 03").font(.caption2.weight(.semibold))
                                .foregroundStyle(imageURL == nil ? Theme.brandInk : .white)
                        }
                        Spacer()
                    }.padding(12)
                }
                .frame(height: 160)
                .accessibilityHidden(true)
                gameRow(.guess, profile: profile, emblemSize: 36)
                    .padding(.horizontal, 12).padding(.vertical, 7)
                Divider().padding(.horizontal, 12)
                HStack {
                    Text(profile.guessCompleted ? "YOUR GUESS IS IN" : "ONE IMAGE. YOUR BEST GUESS.")
                        .font(.caption2).foregroundStyle(.secondary)
                    Spacer()
                    Text("40 points").font(.caption.weight(.semibold)).foregroundStyle(Theme.accent)
                }.padding(.horizontal, 12).padding(.vertical, 7)
            }
            .premiumSurface(cornerRadius: 18)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(profile.guessCompleted
            ? "Guess the Prompt, completed. Similarity \(profile.guessScore.formatted()) out of 10. Review your guess."
            : "Guess the Prompt. One daily image, 40 possible points.")
    }

    private func heroPlaceholder(loading: Bool) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "photo.badge.magnifyingglass").font(.largeTitle)
            Text(loading ? "Finding today’s image…" : "Today’s image isn’t ready yet")
                .font(.subheadline.weight(.medium))
            if !loading { Text("Pull to refresh in a little while.").font(.caption).foregroundStyle(.secondary) }
        }
        .foregroundStyle(Theme.brandInk)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.guessSurface)
    }

    private func compactGame(_ game: BlipzGame, profile: UserProfile) -> some View {
        gameLink(game, profile: profile) {
            gameRow(game, profile: profile, emblemSize: 48)
                .padding(10)
                .premiumSurface(cornerRadius: 16, shadow: false)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func gameLink<Label: View>(_ game: BlipzGame, profile: UserProfile, @ViewBuilder label: () -> Label) -> some View {
        if content != nil || profile.isCompleted(game) {
            NavigationLink(value: game, label: label)
        } else {
            label().accessibilityElement(children: .combine)
                .accessibilityHint("Today’s content is unavailable. Pull to refresh.")
        }
    }

    private func gameRow(_ game: BlipzGame, profile: UserProfile, emblemSize: CGFloat) -> some View {
        HStack(alignment: .center, spacing: 11) {
            BlipzGameEmblem(game: game, size: emblemSize)
            VStack(alignment: .leading, spacing: 3) {
                Text(title(game)).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.brandInk)
                Text(subtitle(game, profile: profile))
                    .font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 2)
            if profile.isCompleted(game) {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.accent)
                    .accessibilityLabel("Completed")
            } else {
                if game != .guess, !dynamicTypeSize.isAccessibilitySize {
                    Text("30 pts").font(.caption2).foregroundStyle(.secondary)
                }
                Image(systemName: content == nil ? "clock" : "arrow.up.right").font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.accent).accessibilityHidden(true)
            }
        }.frame(minHeight: 44)
    }

    private func title(_ game: BlipzGame) -> String {
        switch game {
        case .guess: "Guess the Prompt"
        case .maths: "Quick Maths"
        case .trivia: "Daily Trivia"
        }
    }

    private func subtitle(_ game: BlipzGame, profile: UserProfile) -> String {
        if profile.isCompleted(game) {
            switch game {
            case .guess: return "\(profile.guessScore.formatted(.number.precision(.fractionLength(1)))) / 10 similarity · Review"
            case .maths:
                if let time = profile.mathsElapsedSeconds {
                    return "\(time.formatted(.number.precision(.fractionLength(1)))) seconds · Completed"
                }
                return "\(profile.mathsScore) / 20 correct · Completed"
            case .trivia: return "\(profile.triviaScore) / 5 correct · Review"
            }
        }
        switch game {
        case .guess: return "One strange image. Your best guess."
        case .maths: return "20 problems · Against the clock"
        case .trivia: return "5 questions · A little of everything"
        }
    }

    private func dailyProgress(_ profile: UserProfile) -> some View {
        let count = BlipzGame.orderedDaily.filter { profile.isCompleted($0) }.count
        return VStack(spacing: 9) {
            HStack {
                Text("Your daily progress").font(.caption.weight(.semibold))
                Spacer()
                Text("\(count) / 3").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
            }
            HStack(spacing: 5) {
                ForEach(0..<3) { index in
                    Capsule().fill(index < count ? Theme.accent : Theme.hairline)
                        .frame(height: 5)
                }
            }.accessibilityHidden(true)
            HStack(alignment: .firstTextBaseline) {
                Text(count == 3 ? "A little play went a long way." : "A little play goes a long way.")
                    .font(.caption).foregroundStyle(.secondary)
                Spacer(minLength: 8)
                Text(displayedTotal, format: .number.precision(.fractionLength(0...1)))
                    .font(.blipzDisplay(size: 22, weight: .bold))
                    .foregroundStyle(Theme.brandInk)
                    .contentTransition(.numericText(value: displayedTotal))
                Text("/ 100").font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 3)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.3), value: count)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(count) of 3 games complete. Daily score \(profile.totalScore.formatted()) out of 100.")
    }

    @ViewBuilder
    private func nextAction(_ profile: UserProfile) -> some View {
        if let next = BlipzGame.orderedDaily.first(where: { !profile.isCompleted($0) }) {
            if contentUnavailable {
                Button("Refresh today’s Blip") { Task { await refresh() } }
                    .buttonStyle(PrimaryButtonStyle())
            } else {
                NavigationLink(value: next) {
                    Label("Next up: \(title(next))", systemImage: "arrow.right")
                }.buttonStyle(PrimaryButtonStyle()).disabled(content == nil)
            }
        } else {
            ShareLink(item: "My daily Blip: \(profile.totalScore.formatted())/100. Three games. A little more curious.") {
                Label("Share my score", systemImage: "square.and.arrow.up")
            }.buttonStyle(PrimaryButtonStyle())
            Text("All three games complete. Come back for a fresh Blip tomorrow.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private var boardLink: some View {
        Button {
            Haptics.light()
            router.selected = .ranks
        } label: {
            HStack {
                Label("Today’s board", systemImage: "globe.americas")
                Spacer()
                Image(systemName: "arrow.right").accessibilityHidden(true)
            }
            .font(.subheadline).foregroundStyle(Theme.accent)
            .frame(minHeight: 44)
        }.buttonStyle(.plain)
    }
}
