import SwiftUI

struct GuessGameView: View {
    @State private var viewModel = GuessGameViewModel()
    @State private var profileViewModel = ProfileViewModel()
    @State private var displayedScore: Double = 0
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            GameModalBar(title: viewModel.result == nil ? "GUESS THE PROMPT" : "GUESS · RESULT") {
                Text("1/3")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 14)
            .padding(.top, 4)

            ScrollView {
                if let result = viewModel.result {
                    resultContent(result)
                } else {
                    playContent
                }
            }
        }
        .screenBackground()
        .toolbar(.hidden, for: .navigationBar)
        .task {
            await viewModel.loadDailyContent()
            await profileViewModel.loadProfile()
        }
        .onDisappear {
            viewModel.cancelSubmission()
        }
        .onChange(of: viewModel.result?.score) { _, newScore in
            guard let newScore else { return }
            displayedScore = 0
            withAnimation(.easeOut(duration: 0.6)) { displayedScore = newScore }
        }
    }

    // MARK: - Play (§3)

    private var playContent: some View {
        VStack(spacing: 20) {
            imageView(aspectRatio: 4.0 / 5.0)

            VStack(alignment: .leading, spacing: 16) {
                Text("What prompt made this?")
                    .font(.title3.weight(.medium))

                TextField("type your guess…", text: $viewModel.guessText, axis: .vertical)
                    .textFieldStyle(.plain)
                    .lineLimit(3...6)
                    .padding(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(Color.primary.opacity(0.85), lineWidth: 1.5)
                    )

                Text("One shot. Scored on how close you get.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(Theme.error)
                }

                submitButton
            }
            .padding(.horizontal, 18)
        }
        .padding(.top, 16)
        .padding(.bottom, 24)
    }

    private var submitButton: some View {
        Group {
            if viewModel.isSubmitting {
                HStack(spacing: 8) {
                    ProgressView()
                    Text(viewModel.isScoring ? "Scoring your guess…" : "Submitting…")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .accessibilityElement(children: .combine)
                .accessibilityLabel(viewModel.isScoring ? "Scoring your guess, please wait" : "Submitting your guess")
            } else {
                Button("Submit guess") {
                    Haptics.light()
                    viewModel.submit()
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(viewModel.guessText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }

    // MARK: - Result / reveal (§4)

    private func resultContent(_ result: GuessSubmitResponse) -> some View {
        VStack(spacing: 20) {
            imageView(aspectRatio: 4.0 / 2.6)

            scoreBlock(result)

            VStack(alignment: .leading, spacing: 16) {
                labeledText(overline: "YOU SAID", overlineColor: .secondary, text: result.guess)
                labeledText(overline: "ACTUAL PROMPT", overlineColor: Theme.accent, text: result.actualPrompt ?? "—")
            }
            .padding(.horizontal, 18)

            nextButton
                .padding(.horizontal, 18)
        }
        .padding(.top, 16)
        .padding(.bottom, 24)
    }

    private func scoreBlock(_ result: GuessSubmitResponse) -> some View {
        VStack(spacing: 4) {
            Text(displayedScore, format: .number.precision(.fractionLength(1)))
                .font(.system(size: 52, weight: .bold, design: .rounded))
                .contentTransition(.numericText(value: displayedScore))
            Text("out of 10 · \(qualifier(for: result.score))")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 22)
        .outlinedContainer(emphasized: true)
        .padding(.horizontal, 18)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Score \(result.score, specifier: "%.1f") out of 10, \(qualifier(for: result.score))")
    }

    private func qualifier(for score: Double) -> String {
        switch score {
        case 9...10: return "nailed it"
        case 7..<9: return "close"
        case 4..<7: return "warm"
        default: return "not quite"
        }
    }

    private func labeledText(overline: String, overlineColor: Color, text: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(overline)
                .font(.caption2.weight(.bold))
                .tracking(1.2)
                .foregroundStyle(overlineColor)
            Text(text)
                .font(.body)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // Chains directly into the next unplayed game rather than dumping the player back
    // on Today — see BlipzGame.nextUnplayed. When Guess is the last unplayed game, the
    // button just closes back to Today's already-complete recap instead.
    @ViewBuilder
    private var nextButton: some View {
        if let profile = profileViewModel.profile, let next = BlipzGame.guess.nextUnplayed(in: profile) {
            NavigationLink {
                nextDestination(next)
            } label: {
                Text("Next: \(nextGameLabel(next))")
            }
            .buttonStyle(PrimaryButtonStyle())
            .simultaneousGesture(TapGesture().onEnded { Haptics.light() })
        } else {
            Button {
                Haptics.light()
                dismiss()
            } label: {
                Text("See today's score")
            }
            .buttonStyle(PrimaryButtonStyle())
        }
    }

    @ViewBuilder
    private func nextDestination(_ game: BlipzGame) -> some View {
        switch game {
        case .maths: MathGameView().toolbar(.hidden, for: .tabBar)
        case .trivia: TriviaGameView().toolbar(.hidden, for: .tabBar)
        case .guess: EmptyView()
        }
    }

    private func nextGameLabel(_ game: BlipzGame) -> String {
        switch game {
        case .maths: return "quick maths"
        case .trivia: return "trivia"
        case .guess: return ""
        }
    }

    // MARK: - Image (shared between play and result — result uses a shorter crop)

    private func imageView(aspectRatio: CGFloat) -> some View {
        Group {
            if let url = viewModel.imageUrl {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    case .failure:
                        imageFallback
                    default:
                        imageLoadingOrFallback
                    }
                }
            } else {
                imageLoadingOrFallback
            }
        }
        .aspectRatio(aspectRatio, contentMode: .fit)
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.85), lineWidth: 1)
        )
        .padding(.horizontal, 18)
        .accessibilityLabel("Today's mystery image")
    }

    @ViewBuilder
    private var imageLoadingOrFallback: some View {
        if viewModel.isLoading {
            ProgressView()
                .accessibilityLabel("Loading today's Blip")
        } else {
            imageFallback
        }
    }

    private var imageFallback: some View {
        VStack(spacing: 8) {
            Image(systemName: "photo.badge.exclamationmark")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("Couldn't load today's Blip")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    GuessGameView()
}
