import SwiftUI

struct TriviaGameView: View {
    @State private var viewModel = TriviaGameViewModel()
    @State private var profileViewModel = ProfileViewModel()
    @State private var selectedOptionId: String?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            GameModalBar(title: "TRIVIA") {
                if viewModel.result == nil, !viewModel.questions.isEmpty {
                    Text("\(min(viewModel.currentIndex + 1, viewModel.questions.count))/\(viewModel.questions.count)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    Color.clear
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 4)

            ScrollView {
                if let result = viewModel.result {
                    finishedContent(result)
                } else if let question = viewModel.currentQuestion {
                    VStack(alignment: .leading, spacing: 20) {
                        segmentProgress
                        questionAndAnswers(question)
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 8)
                    .padding(.bottom, 16)
                } else if let error = viewModel.errorMessage {
                    Text(error)
                        .foregroundStyle(Theme.error)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                        .padding(.top, 60)
                } else if viewModel.isLoading {
                    ProgressView()
                        .accessibilityLabel("Loading today's trivia")
                        .padding(.top, 60)
                }
            }

            // Pinned outside the ScrollView so it sits at the bottom of the screen
            // instead of floating directly under the answer rows with empty space
            // below it — the answer list stays top-aligned and scrolls independently.
            if viewModel.result == nil, let question = viewModel.currentQuestion {
                lockInButton(question)
                    .padding(.horizontal, 18)
                    .padding(.top, 12)
                    .safeAreaPadding(.bottom, 16)
            }
        }
        .screenBackground()
        .toolbar(.hidden, for: .navigationBar)
        .task {
            await viewModel.loadDailyContent()
            await profileViewModel.loadProfile()
        }
    }

    // MARK: - Progress (five 3px segments, green for answered)

    private var segmentProgress: some View {
        HStack(spacing: 6) {
            ForEach(0..<max(viewModel.questions.count, 1), id: \.self) { index in
                Rectangle()
                    .fill(index < viewModel.currentIndex ? Theme.accent : Color(.systemGray4))
                    .frame(height: 3)
            }
        }
        .animation(.easeOut(duration: 0.2), value: viewModel.currentIndex)
        .accessibilityHidden(true)
    }

    // MARK: - Question / answers

    private func questionAndAnswers(_ question: TriviaQuestion) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(question.question)
                .font(.title2.weight(.medium))
                .frame(maxWidth: .infinity, alignment: .leading)
                .id(question.question)
                .transition(.opacity)

            VStack(spacing: 10) {
                ForEach(Array(question.options.enumerated()), id: \.offset) { index, option in
                    optionRow(option, optionId: triviaOptionIds[index])
                }
            }
        }
        .animation(.easeOut(duration: 0.2), value: selectedOptionId)
    }

    private func lockInButton(_ question: TriviaQuestion) -> some View {
        Button("Lock it in") {
            lockIn(question)
        }
        .buttonStyle(PrimaryButtonStyle())
        .disabled(selectedOptionId == nil)
    }

    // Black text on a 1px light border; selected is a dark border plus a pale green
    // fill — never green-on-green (that reads as four separate primary buttons).
    private func optionRow(_ option: String, optionId: String) -> some View {
        let isSelected = selectedOptionId == optionId
        return Button {
            Haptics.light()
            selectedOptionId = optionId
        } label: {
            Text(option)
                .font(.body)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .background(
                    isSelected ? Theme.accentWash : Color.clear,
                    in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(isSelected ? Color.primary.opacity(0.85) : Theme.hairline, lineWidth: isSelected ? 1.5 : 1)
                )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // Correctness is never revealed per-question during play — the backend only
    // returns real answers once the full set is submitted (see PRODUCTION_AUDIT.md's
    // Trivia grading fix) — so locking in just records the pick and advances.
    private func lockIn(_ question: TriviaQuestion) {
        guard let selectedOptionId else { return }
        Haptics.light()
        viewModel.selectAnswer(questionId: question.id, selectedOptionId: selectedOptionId)
        self.selectedOptionId = nil
    }

    // MARK: - Finished
    //
    // No dedicated wireframe frame for Trivia's post-submit state. Keeps the existing,
    // valuable per-question review (correctness is finally safe to reveal here) but
    // restyled to the new language — hairline rows instead of colored-fill cards — plus
    // the same chain-to-next-game pattern as Guess/Maths.

    private func finishedContent(_ result: TriviaSubmitResponse) -> some View {
        VStack(spacing: 20) {
            VStack(spacing: 4) {
                Text("\(result.correct)/\(result.total)")
                    .font(.system(size: 52, weight: .bold, design: .rounded))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 22)
            .outlinedContainer(emphasized: true)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Trivia, \(result.correct) out of \(result.total), complete")

            if let review = viewModel.review {
                VStack(spacing: 0) {
                    Divider()
                    ForEach(Array(review.enumerated()), id: \.offset) { index, item in
                        TriviaReviewRow(index: index + 1, item: item)
                        Divider()
                    }
                }
            }

            nextButton
        }
        .padding(.horizontal, 18)
        .padding(.top, 16)
        .padding(.bottom, 24)
        .transition(.opacity)
    }

    @ViewBuilder
    private var nextButton: some View {
        if let profile = profileViewModel.profile, let next = BlipzGame.trivia.nextUnplayed(in: profile) {
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
        case .guess: GuessGameView().toolbar(.hidden, for: .tabBar)
        case .maths: MathGameView().toolbar(.hidden, for: .tabBar)
        case .trivia: EmptyView()
        }
    }

    private func nextGameLabel(_ game: BlipzGame) -> String {
        switch game {
        case .guess: return "guess the prompt"
        case .maths: return "quick maths"
        case .trivia: return ""
        }
    }
}

private struct TriviaReviewRow: View {
    let index: Int
    let item: TriviaReviewQuestion

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: item.isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundStyle(item.isCorrect ? Theme.success : Theme.error)
                Text("Q\(index)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
            }
            Text(item.question)
                .font(.subheadline.weight(.medium))

            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(item.options.enumerated()), id: \.offset) { idx, option in
                    optionRow(option, optionId: triviaOptionIds[idx])
                }
            }
        }
        .padding(.vertical, 14)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "Question \(index): \(item.question). "
                + (item.isCorrect ? "You answered correctly." : "You answered incorrectly — correct answer was \(item.correctAnswerText).")
        )
    }

    // Matched by stable A/B/C/D optionId, never by comparing text — see
    // PRODUCTION_AUDIT.md's Trivia grading fix.
    private func optionRow(_ option: String, optionId: String) -> some View {
        let isCorrectAnswer = optionId == item.correctOptionId
        let isUserWrongPick = optionId == item.selectedOptionId && !item.isCorrect

        return HStack(spacing: 8) {
            Group {
                if isCorrectAnswer {
                    Image(systemName: "checkmark").foregroundStyle(Theme.success)
                } else if isUserWrongPick {
                    Image(systemName: "xmark").foregroundStyle(Theme.error)
                } else {
                    Color.clear
                }
            }
            .frame(width: 16)
            .font(.caption.weight(.bold))

            Text(option)
                .font(.subheadline)
                .foregroundStyle(isCorrectAnswer || isUserWrongPick ? .primary : .secondary)
        }
    }
}

#Preview {
    TriviaGameView()
}
