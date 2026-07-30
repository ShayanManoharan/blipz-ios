import SwiftUI

struct TriviaGameView: View {
    @State private var viewModel = TriviaGameViewModel()
    @State private var selectedOption: String?
    @ScaledMetric(relativeTo: .title) private var headerFontSize: CGFloat = 28

    var body: some View {
        VStack(spacing: 20) {
            header

            if let result = viewModel.result {
                resultAndReview(result)
                    .transition(.scale.combined(with: .opacity))
            } else if let question = viewModel.currentQuestion {
                progressBar
                questionCard(question)
            } else if let error = viewModel.errorMessage {
                Text(error)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            } else if viewModel.isLoading {
                ProgressView()
            }
        }
        .padding()
        .screenBackground()
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: viewModel.result != nil)
        .task {
            await viewModel.loadDailyContent()
        }
    }

    private var header: some View {
        VStack(spacing: 4) {
            Text("Daily Trivia")
                .font(.system(size: headerFontSize, weight: .bold, design: .rounded))
            Text("Five questions, once a day.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }

    private var progressBar: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Question \(viewModel.currentIndex + 1) of \(viewModel.questions.count)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            ProgressView(value: Double(viewModel.currentIndex), total: Double(viewModel.questions.count))
                .tint(Theme.accent)
        }
    }

    private func questionCard(_ question: TriviaQuestion) -> some View {
        VStack(spacing: 20) {
            Text(question.question)
                .font(.title2)
                .bold()
                .multilineTextAlignment(.center)
                .id(question.question)
                .transition(.opacity)

            VStack(spacing: 12) {
                ForEach(question.options, id: \.self) { option in
                    Button(option) {
                        select(option)
                    }
                    .buttonStyle(OptionButtonStyle(state: selectedOption == option ? .selected : .normal))
                    .disabled(selectedOption != nil)
                }
            }
        }
        .cardStyle()
        .animation(.easeOut(duration: 0.25), value: viewModel.currentIndex)
        .animation(.easeOut(duration: 0.2), value: selectedOption)
    }

    // The backend never sends trivia answers to the client before completion (see
    // PublicTriviaQuestion), so correctness can't be revealed per-question during
    // play anymore. Once submitted, GET /games/trivia-review safely returns the real
    // correct answers (safe precisely because one-attempt-per-day is now enforced —
    // there's no further submission left to exploit with this knowledge), and this
    // is where the green/red feedback comes back, all at once.
    private func select(_ option: String) {
        guard selectedOption == nil else { return }
        selectedOption = option
        Haptics.light()

        Task {
            try? await Task.sleep(for: .milliseconds(350))
            viewModel.selectAnswer(option)
            selectedOption = nil
        }
    }

    @ViewBuilder
    private func resultAndReview(_ result: TriviaSubmitResponse) -> some View {
        ScrollView {
            VStack(spacing: 16) {
                ResultCard(title: "\(result.correct)/\(result.total)", subtitle: "Nice work today!")

                if let review = viewModel.review {
                    VStack(spacing: 12) {
                        ForEach(Array(review.enumerated()), id: \.offset) { index, item in
                            TriviaReviewCard(index: index + 1, item: item)
                        }
                    }
                }
            }
        }
    }
}

private struct TriviaReviewCard: View {
    let index: Int
    let item: TriviaReviewQuestion

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Text("Q\(index)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                Image(systemName: item.isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundStyle(item.isCorrect ? Theme.success : .red)
            }
            Text(item.question)
                .font(.subheadline.weight(.semibold))

            VStack(spacing: 6) {
                ForEach(item.options, id: \.self) { option in
                    optionRow(option)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "Question \(index): \(item.question). "
                + (item.isCorrect ? "You answered correctly." : "You answered incorrectly — correct answer was \(item.correctAnswer).")
        )
    }

    private func optionRow(_ option: String) -> some View {
        let isCorrectAnswer = option == item.correctAnswer
        let isUserWrongPick = option == item.selectedAnswer && !item.isCorrect
        let highlighted = isCorrectAnswer || isUserWrongPick

        return HStack {
            Text(option)
                .font(.subheadline)
            Spacer()
            if isCorrectAnswer {
                Image(systemName: "checkmark")
            } else if isUserWrongPick {
                Image(systemName: "xmark")
            }
        }
        .foregroundStyle(highlighted ? .white : .primary)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(isCorrectAnswer ? Theme.success : (isUserWrongPick ? .red : Theme.cardBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Theme.accent.opacity(highlighted ? 0 : 0.2), lineWidth: 1)
        )
    }
}

#Preview {
    TriviaGameView()
}
