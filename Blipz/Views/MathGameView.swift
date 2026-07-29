import SwiftUI

struct MathGameView: View {
    @State private var viewModel = MathGameViewModel()

    var body: some View {
        VStack(spacing: 24) {
            if let result = viewModel.result {
                Text("You got \(result.correct)/\(result.total)!")
                    .font(.title)
                    .bold()
            } else if let problem = viewModel.currentProblem {
                Text("Problem \(viewModel.currentIndex + 1) of \(viewModel.problems.count)")
                    .foregroundStyle(.secondary)
                Text(problem.question)
                    .font(.system(size: 40, weight: .bold))
                TextField("Answer", text: $viewModel.currentAnswerText)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.numbersAndPunctuation)
                    .multilineTextAlignment(.center)
                    .font(.title2)
                    .padding(.horizontal, 40)
                Button("Submit") {
                    viewModel.submitCurrentAnswer()
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.currentAnswerText.isEmpty)
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
    MathGameView()
}
