import SwiftUI

struct GuessGameView: View {
    @State private var viewModel = GuessGameViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if let result = viewModel.result {
                    ResultCard(
                        title: String(format: "%.1f/10", result.score),
                        subtitle: "Your guess: \(result.guess)"
                    )
                    .transition(.scale.combined(with: .opacity))
                } else {
                    AsyncImage(url: viewModel.imageUrl) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFit()
                                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                                .shadow(color: .black.opacity(0.1), radius: 12, y: 6)
                        case .failure:
                            Color.gray.opacity(0.2)
                                .frame(height: 300)
                                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                                .overlay(Text("Couldn't load image"))
                        default:
                            ProgressView()
                                .frame(height: 300)
                        }
                    }

                    VStack(spacing: 12) {
                        TextField("What do you see?", text: $viewModel.guessText)
                            .textFieldStyle(.roundedBorder)

                        Button("Submit Guess") {
                            Task { await viewModel.submitGuess() }
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(viewModel.guessText.isEmpty)
                    }
                    .cardStyle()
                }

                if let error = viewModel.errorMessage {
                    Text(error)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                if viewModel.isLoading {
                    ProgressView()
                }
            }
            .padding()
        }
        .screenBackground()
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: viewModel.result != nil)
        .task {
            await viewModel.loadDailyContent()
        }
    }
}

#Preview {
    GuessGameView()
}
