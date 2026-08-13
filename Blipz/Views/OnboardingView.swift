import SwiftUI

// First-launch, single-screen explainer — see RootView (gates it behind
// hasCompletedOnboarding, shown before any network/auth work is relevant) and YouView
// (a plain replay row, no AppStorage side effect). No backend dependency: everything
// here is static copy, so it renders instantly even offline.
struct OnboardingView: View {
    let onFinish: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private struct GameBlurb: Identifiable {
        let id: String
        let game: BlipzGame
        let title: String
        let description: String
    }

    private static let games: [GameBlurb] = [
        GameBlurb(
            id: "guess", game: .guess, title: "AI Guess",
            description: "Describe today's AI-generated image and see how close you get."
        ),
        GameBlurb(
            id: "maths", game: .maths, title: "Quick Maths",
            description: "Solve 20 problems as fast as you can."
        ),
        GameBlurb(
            id: "trivia", game: .trivia, title: "Daily Trivia",
            description: "Answer 5 new questions."
        ),
    ]

    var body: some View {
        GeometryReader { geo in
            ScrollView {
                VStack(spacing: 32) {
                    Spacer(minLength: 12)

                    VStack(spacing: 8) {
                        Text("BLIPZ")
                            .font(.blipzDisplay(size: 34, weight: .bold))
                            .tracking(34 * 0.1)
                        Text("Three games. One new challenge every day.")
                            .font(.title3.weight(.medium))
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 22) {
                        ForEach(Self.games) { game in
                            gameRow(game)
                        }
                    }

                    Text("Complete all three. Build your streak. Climb the daily ranks.")
                        .font(.subheadline.weight(.medium))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 12)

                    Spacer(minLength: 12)

                    Button {
                        Haptics.light()
                        onFinish()
                    } label: {
                        Text("Play today's Blip")
                    }
                    .buttonStyle(PrimaryButtonStyle())
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 24)
                .frame(minHeight: geo.size.height)
            }
        }
        .screenBackground()
    }

    private func gameRow(_ game: GameBlurb) -> some View {
        HStack(spacing: 16) {
            BlipzGameEmblem(game: game.game, size: 44)

            VStack(alignment: .leading, spacing: 2) {
                Text(game.title)
                    .font(.headline)
                Text(game.description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(game.title). \(game.description)")
    }
}

#Preview {
    OnboardingView(onFinish: {})
}

#Preview("Dark") {
    OnboardingView(onFinish: {})
        .preferredColorScheme(.dark)
}
