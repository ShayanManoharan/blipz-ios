import SwiftUI

struct TriviaGameView: View {
    @State private var viewModel = TriviaGameViewModel()
    @State private var selectedOption: String?
    @ScaledMetric(relativeTo: .title) private var headerFontSize: CGFloat = 28

    var body: some View {
        VStack(spacing: 20) {
            header

            if let result = viewModel.result {
                ResultCard(title: "\(result.correct)/\(result.total)", subtitle: "Nice work today!")
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

    // The backend never sends trivia answers to the client (see PublicTriviaQuestion),
    // so correctness can't be revealed per-question anymore — only the aggregate
    // correct/total from POST /games/submit-trivia, shown on the result screen.
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
}

#Preview {
    TriviaGameView()
}
