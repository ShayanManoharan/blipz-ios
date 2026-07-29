import SwiftUI

struct GuessGameView: View {
    @State private var viewModel = GuessGameViewModel()
    @State private var profileViewModel = ProfileViewModel()
    @State private var displayedScore: Double = 0
    @Environment(\.displayScale) private var displayScale

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                header

                if let result = viewModel.result {
                    completedContent(result: result)
                } else {
                    imageCard
                    composer
                }

                if let error = viewModel.errorMessage {
                    Text(error)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                if viewModel.result == nil, viewModel.imageUrl == nil, viewModel.isLoading {
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
        .onChange(of: viewModel.result?.score) { _, newScore in
            guard let newScore else { return }
            Task { await profileViewModel.loadProfile() }
            displayedScore = 0
            withAnimation(.easeOut(duration: 1.2)) {
                displayedScore = newScore
            }
        }
    }

    private var header: some View {
        VStack(spacing: 4) {
            Text("Today's Blip")
                .font(.system(size: 28, weight: .bold, design: .rounded))
            Text("Everyone sees the same image.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var imageCard: some View {
        ZStack {
            Circle()
                .fill(Theme.accent.opacity(0.25))
                .blur(radius: 40)
                .frame(width: 260, height: 260)
                .accessibilityHidden(true)

            AsyncImage(url: viewModel.imageUrl) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .shadow(color: Theme.accent.opacity(0.25), radius: 20, y: 10)
                        .accessibilityLabel("Today's mystery image")
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
        }
    }

    private var composer: some View {
        VStack(spacing: 12) {
            Text("What do you see?")
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity, alignment: .leading)

            TextField("Describe the image…", text: $viewModel.guessText, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(3...5)

            if viewModel.isLoading {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("AI is judging your guess…")
                        .foregroundStyle(.secondary)
                }
            } else {
                Button("Lock In My Guess") {
                    Haptics.light()
                    Task { await viewModel.submitGuess() }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(viewModel.guessText.isEmpty)
            }
        }
        .cardStyle()
    }

    private func completedContent(result: GuessSubmitResponse) -> some View {
        VStack(spacing: 16) {
            Text("Score")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(displayedScore, format: .number.precision(.fractionLength(1)))
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.accent)
                    .contentTransition(.numericText(value: displayedScore))
                Text("/ 10")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Score \(result.score, specifier: "%.1f") out of 10")

            Text("Your guess: \(result.guess)")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            if let profile = profileViewModel.profile {
                let card = ScoreCardRenderer.image(for: profile, displayScale: displayScale)
                ShareLink(item: card, preview: SharePreview("My Blipz Score", image: card)) {
                    Label("Share my score", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(.bordered)
                .tint(Theme.accent)
            }
        }
        .cardStyle()
        .transition(.scale.combined(with: .opacity))
    }
}

#Preview {
    GuessGameView()
}
