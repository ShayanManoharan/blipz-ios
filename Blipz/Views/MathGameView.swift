import SwiftUI

struct MathGameView: View {
    @State private var viewModel = MathGameViewModel()
    @FocusState private var answerFieldFocused: Bool
    @ScaledMetric(relativeTo: .title) private var headerFontSize: CGFloat = 28
    @ScaledMetric(relativeTo: .largeTitle) private var problemFontSize: CGFloat = 48

    var body: some View {
        VStack(spacing: 24) {
            header

            switch viewModel.phase {
            case .notStarted:
                notStartedContent
            case .playing:
                playingContent
            case .finished:
                finishedContent
            }

            if let error = viewModel.errorMessage {
                Text(error)
                    .foregroundStyle(Theme.error)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
        }
        .padding()
        .screenBackground()
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: viewModel.phase)
        .task {
            await viewModel.loadDailyContent()
        }
    }

    private var header: some View {
        VStack(spacing: 4) {
            Text("Quick Maths")
                .font(.system(size: headerFontSize, weight: .bold, design: .rounded))
            Text("Answer all 20 as fast as you can.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }

    private var notStartedContent: some View {
        VStack(spacing: 20) {
            Image(systemName: "bolt.fill")
                .font(.system(size: 44))
                .foregroundStyle(Theme.accent)

            if viewModel.isLoading {
                ProgressView()
                    .accessibilityLabel("Loading today's problems")
            } else {
                Button("Play") {
                    answerFieldFocused = true
                    viewModel.start()
                }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.horizontal, 60)
                .disabled(viewModel.problems.isEmpty)
            }
        }
        .cardStyle()
    }

    private var playingContent: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Question \(viewModel.currentDisplayIndex + 1) of \(viewModel.totalCount)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                if let startDate = viewModel.startDate {
                    TimelineView(.periodic(from: startDate, by: 0.1)) { context in
                        let elapsed = context.date.timeIntervalSince(startDate)
                        Text(elapsedString(elapsed))
                            .font(.system(.subheadline, design: .monospaced))
                            .foregroundStyle(Theme.accent)
                            .accessibilityLabel("Elapsed time: \(String(format: "%.1f", elapsed)) seconds")
                    }
                }
            }

            if let problem = viewModel.currentProblem {
                Text(problem.question)
                    .font(.system(size: problemFontSize, weight: .bold, design: .rounded))
                    .id(viewModel.currentDisplayIndex)
                    .transition(.opacity)

                TextField("Answer", text: $viewModel.currentAnswerText)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.numbersAndPunctuation)
                    .multilineTextAlignment(.center)
                    .font(.title2)
                    .padding(.horizontal, 40)
                    .focused($answerFieldFocused)
                    .onChange(of: viewModel.currentAnswerText) {
                        viewModel.checkAnswer()
                    }
            }
        }
        .cardStyle()
    }

    private var finishedContent: some View {
        ResultCard(
            title: "\(viewModel.result?.correct ?? viewModel.totalCount)/\(viewModel.totalCount)",
            subtitle: viewModel.elapsedTime.map { "Solved in \(elapsedString($0))" } ?? "Nice work today!"
        )
        .transition(.scale.combined(with: .opacity))
    }

    private func elapsedString(_ interval: TimeInterval) -> String {
        String(format: "%.1fs", interval)
    }
}

#Preview {
    MathGameView()
}
