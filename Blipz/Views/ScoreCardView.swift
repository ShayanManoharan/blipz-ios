import SwiftUI

struct ScoreCardView: View {
    let profile: UserProfile
    let dateLabel: String

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Blipz")
                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.accent)
                Spacer()
                Text(dateLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 10) {
                ScoreCardRow(emoji: "🔢", label: "Maths", value: "\(profile.mathsScore)/20")
                ScoreCardRow(emoji: "🖼️", label: "Guess", value: String(format: "%.1f/10", profile.guessScore))
                ScoreCardRow(emoji: "❓", label: "Trivia", value: "\(profile.triviaScore)/5")
            }

            Divider()

            HStack {
                Label("\(profile.currentStreak)-day streak", systemImage: "flame.fill")
                    .foregroundStyle(Theme.streak)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text("Total: \(profile.totalScore, format: .number.precision(.fractionLength(1)))")
                    .font(.headline)
                    .foregroundStyle(Theme.accent)
            }
        }
        .padding(24)
        .frame(width: 320)
        .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.15), radius: 16, y: 8)
    }
}

private struct ScoreCardRow: View {
    let emoji: String
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(emoji)
            Text(label)
            Spacer()
            Text(value).bold()
        }
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
