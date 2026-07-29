import SwiftUI

struct TriviaGameView: View {
    @State private var viewModel = TriviaGameViewModel()
    @State private var selectedOption: String?

    var body: some View {
        VStack(spacing: 24) {
            if let result = viewModel.result {
                ResultCard(title: "\(result.correct)/\(result.total)", subtitle: "Nice work today!")
                    .transition(.scale.combined(with: .opacity))
            } else if let question = viewModel.currentQuestion {
                VStack(spacing: 20) {
                    Text("Question \(viewModel.currentIndex + 1) of \(viewModel.questions.count)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(question.question)
                        .font(.title2)
                        .bold()
                        .multilineTextAlignment(.center)

                    VStack(spacing: 12) {
                        ForEach(question.options, id: \.self) { option in
                            Button(option) {
                                selectedOption = option
                                Task {
                                    try? await Task.sleep(for: .milliseconds(150))
                                    viewModel.selectAnswer(option)
                                    selectedOption = nil
                                }
                            }
                            .buttonStyle(OptionButtonStyle(isSelected: selectedOption == option))
                        }
                    }
                    .animation(.easeOut(duration: 0.15), value: selectedOption)
                }
                .cardStyle()
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
}

#Preview {
    TriviaGameView()
}
