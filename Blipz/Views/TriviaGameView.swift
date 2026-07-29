import SwiftUI

struct TriviaGameView: View {
    @State private var viewModel = TriviaGameViewModel()

    var body: some View {
        VStack(spacing: 24) {
            if let result = viewModel.result {
                Text("You got \(result.correct)/\(result.total)!")
                    .font(.title)
                    .bold()
            } else if let question = viewModel.currentQuestion {
                Text("Question \(viewModel.currentIndex + 1) of \(viewModel.questions.count)")
                    .foregroundStyle(.secondary)
                Text(question.question)
                    .font(.title2)
                    .bold()
                    .multilineTextAlignment(.center)

                VStack(spacing: 12) {
                    ForEach(question.options, id: \.self) { option in
                        Button(option) {
                            viewModel.selectAnswer(option)
                        }
                        .buttonStyle(.bordered)
                        .frame(maxWidth: .infinity)
                    }
                }
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
        .task {
            await viewModel.loadDailyContent()
        }
    }
}

#Preview {
    TriviaGameView()
}
