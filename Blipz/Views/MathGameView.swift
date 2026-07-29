import SwiftUI

struct MathGameView: View {
    @State private var viewModel = MathGameViewModel()

    var body: some View {
        VStack(spacing: 24) {
            if let result = viewModel.result {
                ResultCard(title: "\(result.correct)/\(result.total)", subtitle: "Nice work today!")
                    .transition(.scale.combined(with: .opacity))
            } else if let problem = viewModel.currentProblem {
                VStack(spacing: 16) {
                    Text("Problem \(viewModel.currentIndex + 1) of \(viewModel.problems.count)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(problem.question)
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                    TextField("Answer", text: $viewModel.currentAnswerText)
                        .textFieldStyle(.roundedBorder)
                        .keyboardType(.numbersAndPunctuation)
                        .multilineTextAlignment(.center)
                        .font(.title2)
                        .padding(.horizontal, 40)
                    Button("Submit") {
                        viewModel.submitCurrentAnswer()
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .padding(.horizontal, 40)
                    .disabled(viewModel.currentAnswerText.isEmpty)
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
    MathGameView()
}
