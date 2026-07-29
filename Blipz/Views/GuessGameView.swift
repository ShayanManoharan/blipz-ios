import SwiftUI

struct GuessGameView: View {
    @State private var viewModel = GuessGameViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if let result = viewModel.result {
                    Text("Score: \(result.score, specifier: "%.1f")/10")
                        .font(.title)
                        .bold()
                    Text("Your guess: \(result.guess)")
                        .foregroundStyle(.secondary)
                } else {
                    AsyncImage(url: viewModel.imageUrl) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFit()
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        case .failure:
                            Color.gray.opacity(0.2)
                                .frame(height: 300)
                                .overlay(Text("Couldn't load image"))
                        default:
                            ProgressView()
                                .frame(height: 300)
                        }
                    }

                    TextField("What do you see?", text: $viewModel.guessText)
                        .textFieldStyle(.roundedBorder)

                    Button("Submit Guess") {
                        Task { await viewModel.submitGuess() }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(viewModel.guessText.isEmpty)
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
        .task {
            await viewModel.loadDailyContent()
        }
    }
}

#Preview {
    GuessGameView()
}
