import SwiftUI

struct ScoreCardView: View {
    let profile: UserProfile
    let dateLabel: String

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("BLIPZ · \(dateLabel.uppercased())")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .tracking(1.5)

            Text(profile.totalScore, format: .number.precision(.fractionLength(1)))
                .font(.system(size: 40, weight: .bold, design: .rounded))

            // The only place emoji appear in the product — a Wordle-style proportional
            // square row per game, guess/maths/trivia in that fixed order.
            VStack(alignment: .leading, spacing: 4) {
                squareRow(score: profile.guessScore, max: 10)
                squareRow(score: Double(profile.mathsScore), max: 20)
                squareRow(score: Double(profile.triviaScore), max: 5)
            }
            .font(.system(size: 15))

            Text("guess · maths · trivia")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .frame(width: 230, alignment: .leading)
        .outlinedContainer(emphasized: true)
    }

    private func squareRow(score: Double, max: Double) -> some View {
        let filled = max > 0 ? Int((score / max * 5).rounded()) : 0
        let clamped = min(5, Swift.max(0, filled))
        return Text(String(repeating: "🟩", count: clamped) + String(repeating: "⬛", count: 5 - clamped))
    }
}

enum ScoreCardRenderer {
    static func image(for profile: UserProfile, displayScale: CGFloat) -> Image {
        let dateLabel = Date.now.formatted(.dateTime.month(.abbreviated).day())
        let renderer = ImageRenderer(content: ScoreCardView(profile: profile, dateLabel: dateLabel))
        renderer.scale = displayScale
        guard let uiImage = renderer.uiImage else {
            return Image(systemName: "square.and.arrow.up")
        }
        return Image(uiImage: uiImage)
    }
}

#Preview {
    ScoreCardView(
        profile: UserProfile(
            id: "1", username: "shayan", currentStreak: 4, longestStreak: 7,
            mathsScore: 17, triviaScore: 4, guessScore: 8.5, totalScore: 29.5,
            mathsCompleted: true, guessCompleted: true, triviaCompleted: true
        ),
        dateLabel: "Jul 29"
    )
}
