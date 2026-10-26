import SwiftUI

struct DailyRevealView: View {
    let context: DailyRevealContext
    @State private var viewModel = DailyRevealViewModel()

    @MainActor
    init(context: DailyRevealContext, viewModel: DailyRevealViewModel? = nil) {
        self.context = context
        _viewModel = State(initialValue: viewModel ?? DailyRevealViewModel())
    }

    var body: some View {
        ScrollView {
            if let profile = viewModel.profile {
                DailyRevealContent(
                    profile: profile, date: context.date, review: viewModel.review,
                    imageURL: viewModel.imageURL, globalRank: viewModel.globalRank,
                    friendsRank: viewModel.friendsRank,
                    promptUnavailable: viewModel.promptUnavailable,
                    retry: { Task { await viewModel.load(for: context) } },
                    back: { DailyRevealCoordinator.shared.backToToday() }
                )
            } else {
                VStack(spacing: 24) {
                    BlipzWordmark()
                    if let error = viewModel.errorMessage {
                        Text(error).foregroundStyle(.secondary).multilineTextAlignment(.center)
                        Button("Try again") { Task { await viewModel.load(for: context) } }
                            .buttonStyle(PrimaryButtonStyle())
                    } else { ProgressView("Opening your Daily Reveal…") }
                    Button("Back to Today") { DailyRevealCoordinator.shared.backToToday() }
                        .frame(minHeight: 44)
                }.padding(24).padding(.top, 32)
            }
        }
        .screenBackground()
        .task {
            if viewModel.profile == nil && viewModel.errorMessage == nil {
                await viewModel.load(for: context)
            }
        }
    }
}

/// A presentation-only view, fed exclusively by the verified live reveal model.
/// Keeping rendering separate also makes the payoff accessible to snapshot tests.
struct DailyRevealContent: View {
    let profile: UserProfile
    let date: String
    let review: GuessReviewResponse?
    let imageURL: URL?
    let globalRank: Int?
    let friendsRank: Int?
    var promptUnavailable = false
    let retry: () -> Void
    let back: () -> Void
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var displayedScore = 0.0

    var body: some View {
        VStack(spacing: 18) {
            HStack {
                Spacer()
                BlipzWordmark()
                Spacer()
            }.overlay(alignment: .trailing) {
                Button(action: back) { Image(systemName: "xmark").foregroundStyle(.secondary) }
                    .frame(width: 44, height: 44).accessibilityLabel("Back to Today")
            }
            VStack(spacing: 6) {
                Label("DAILY BLIP COMPLETE · \(date)", systemImage: "checkmark.seal")
                    .font(.caption2.weight(.medium)).foregroundStyle(.secondary)
                Text("Brilliant curiosity!").font(.blipzEditorial).foregroundStyle(Theme.brandInk)
                    .multilineTextAlignment(.center).accessibilityAddTraits(.isHeader)
                Text("Three games. One big picture.").font(.caption).foregroundStyle(.secondary)
            }
            scoreMedallion
            if let breakdown = DailyScoreBreakdown(profile: profile) {
                breakdownCards(breakdown)
            } else {
                Text("Your final score is saved. A points breakdown isn’t available.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            promptCard
            standings
            ShareLink(item: shareText) {
                Label("Share my score", systemImage: "square.and.arrow.up")
            }.buttonStyle(PrimaryButtonStyle())
            Button("Back to Today", action: back)
                .font(.subheadline.weight(.semibold)).foregroundStyle(Theme.accent)
                .frame(minHeight: 44)
        }
        .padding(.horizontal, 20).padding(.top, 12).padding(.bottom, 24)
        .task(id: profile.totalScore) {
            guard !reduceMotion else { displayedScore = profile.totalScore; return }
            for step in 1...20 {
                do { try await Task.sleep(for: .milliseconds(20)) } catch { return }
                displayedScore = profile.totalScore * Double(step) / 20
            }
        }
    }

    private var scoreMedallion: some View {
        VStack(spacing: 0) {
            Text(displayedScore, format: .number.precision(.fractionLength(0...1)))
                .font(.custom("SpaceGrotesk-Bold", size: 52, relativeTo: .largeTitle))
                .foregroundStyle(Theme.brandInk)
                .contentTransition(.numericText(value: displayedScore))
            Text("/ 100").font(.subheadline).foregroundStyle(Theme.accent)
        }
        .padding(dynamicTypeSize.isAccessibilitySize ? 12 : 32)
        .background {
            if !dynamicTypeSize.isAccessibilitySize {
                ZStack {
                    RoundedRectangle(cornerRadius: 34).fill(Theme.avatarSurface.opacity(0.75))
                        .rotationEffect(.degrees(45))
                    RoundedRectangle(cornerRadius: 34).fill(Theme.avatarSurface.opacity(0.55))
                    Circle().fill(Theme.accentWash)
                }.frame(width: 148, height: 148).accessibilityHidden(true)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Final daily score, \(profile.totalScore.formatted()) out of 100")
    }

    private func breakdownCards(_ breakdown: DailyScoreBreakdown) -> some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(spacing: 10) {
                    resultCard(.guess, points: breakdown.guess, maximum: 40)
                    resultCard(.maths, points: breakdown.maths, maximum: 30)
                    resultCard(.trivia, points: breakdown.trivia, maximum: 30)
                }
            } else {
                HStack(alignment: .top, spacing: 8) {
                    resultCard(.guess, points: breakdown.guess, maximum: 40)
                    resultCard(.maths, points: breakdown.maths, maximum: 30)
                    resultCard(.trivia, points: breakdown.trivia, maximum: 30)
                }
            }
        }
    }

    private func resultCard(_ game: BlipzGame, points: Double, maximum: Int) -> some View {
        VStack(spacing: 7) {
            BlipzGameEmblem(game: game, size: 56, imageURL: game == .guess ? imageURL : nil)
            Text(game.title).font(.caption.weight(.semibold))
                .multilineTextAlignment(.center).foregroundStyle(Theme.brandInk)
            Text("\(points.formatted(.number.precision(.fractionLength(0...1)))) / \(maximum)")
                .font(.subheadline.weight(.semibold)).foregroundStyle(Theme.brandInk)
            Text(rawResult(game)).font(.caption2).foregroundStyle(.secondary)
                .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity).padding(.horizontal, 6).padding(.vertical, 12)
        .premiumSurface(cornerRadius: 14, shadow: false)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(game.title), \(points.formatted()) of \(maximum) points. \(rawResult(game))")
    }

    private func rawResult(_ game: BlipzGame) -> String {
        switch game {
        case .guess: return "\(profile.guessScore.formatted(.number.precision(.fractionLength(1)))) / 10 similarity"
        case .maths:
            if let time = profile.mathsElapsedSeconds {
                return "\(time.formatted(.number.precision(.fractionLength(1)))) seconds"
            }
            return "\(profile.mathsScore) / 20 correct · time not recorded"
        case .trivia: return "\(profile.triviaScore) / 5 correct"
        }
    }

    private var promptCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Today’s prompt was…").font(.caption.weight(.semibold)).foregroundStyle(Theme.brandInk)
            if let review {
                HStack(alignment: .top, spacing: 12) {
                    if !dynamicTypeSize.isAccessibilitySize, imageURL != nil {
                        BlipzGameEmblem(game: .guess, size: 64, imageURL: imageURL)
                    }
                    Text(review.actualPrompt).font(.system(.body, design: .serif))
                        .foregroundStyle(Theme.brandInk).fixedSize(horizontal: false, vertical: true)
                }
                Text("Your guess: \(review.guess)").font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else if promptUnavailable {
                Text("Your result is saved, but the prompt review couldn’t load.")
                    .font(.caption).foregroundStyle(.secondary)
                Button("Retry prompt review", action: retry).frame(minHeight: 44)
            } else {
                ProgressView("Loading the prompt reveal…").font(.caption)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading).padding(14)
        .premiumSurface(cornerRadius: 16, shadow: false)
    }

    private var standings: some View {
        VStack(spacing: 12) {
            Label("\(profile.currentStreak) day streak", systemImage: "flame")
                .foregroundStyle(Theme.brandInk)
            if let globalRank {
                Label("#\(globalRank) global rank", systemImage: "trophy")
                    .foregroundStyle(Theme.brandInk)
            }
            if let friendsRank {
                Label("#\(friendsRank) among friends", systemImage: "person.2")
                    .foregroundStyle(Theme.brandInk)
            }
        }
        .font(.subheadline.weight(.semibold)).frame(maxWidth: .infinity).padding(14)
        .premiumSurface(.accent, cornerRadius: 16, shadow: false)
    }

    private var shareText: String {
        "Blipz · \(date)\n\(profile.totalScore.formatted())/100\nGuess \(profile.guessScore.formatted())/10 · Maths \(profile.mathsElapsedSeconds.map { $0.formatted(.number.precision(.fractionLength(1))) + "s" } ?? "completed") · Trivia \(profile.triviaScore)/5\n\(profile.currentStreak) day streak. A little more curious."
    }
}
