import SwiftUI

// Guess/Maths/Trivia get distinct but coordinated accents so the three widgets read
// as separate games rather than one repeated lavender block. Completed states use
// Theme.success as a secondary signal — these accents are preserved even when a game
// is completed (see BlipzGameEmblem).
enum TodayAccent {
    static let guess = Theme.accent
    static let maths = Color(red: 0.20, green: 0.47, blue: 0.95)
    static let trivia = Color(red: 0.85, green: 0.55, blue: 0.15)
}

enum BlipzGame {
    case guess
    case maths
    case trivia

    var accent: Color {
        switch self {
        case .guess: return TodayAccent.guess
        case .maths: return TodayAccent.maths
        case .trivia: return TodayAccent.trivia
        }
    }

    /// The dominant glyph carrying each game's identity.
    var symbol: String {
        switch self {
        case .guess: return "photo.fill"
        case .maths: return "bolt.fill"
        case .trivia: return "questionmark.bubble.fill"
        }
    }

    /// A small restrained flourish reinforcing identity — nil where the primary
    /// symbol is already compound enough on its own (Trivia's bubble+questionmark).
    var secondarySymbol: String? {
        switch self {
        case .guess: return "sparkles"
        case .maths: return "number"
        case .trivia: return nil
        }
    }

    var accessibilityName: String {
        switch self {
        case .guess: return "AI Prompt Guess"
        case .maths: return "Quick Maths"
        case .trivia: return "Daily Trivia"
        }
    }
}

/// A small branded emblem for one of the three daily games. Built entirely from
/// native shapes + SF Symbols, scaled relative to `size` so it stays crisp from
/// tracker-node size up through hero size.
///
/// Completion is shown as a secondary green ring around the badge — the game's own
/// accent and symbol are never replaced, so a completed game stays identifiable.
struct BlipzGameEmblem: View {
    let game: BlipzGame
    var size: CGFloat = 36
    var isCompleted: Bool = false

    private var cornerRadius: CGFloat { size * 0.28 }
    private var symbolSize: CGFloat { size * 0.44 }
    private var secondarySize: CGFloat { size * 0.2 }
    private var borderWidth: CGFloat { max(1, size * 0.045) }
    private var ringWidth: CGFloat { max(1.5, size * 0.09) }
    private var ringInset: CGFloat { size * 0.12 }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [game.accent, game.accent.opacity(0.72)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(.white.opacity(0.35), lineWidth: borderWidth)
                )
                .frame(width: size, height: size)

            Image(systemName: game.symbol)
                .font(.system(size: symbolSize, weight: .bold))
                .foregroundStyle(.white)

            if let secondarySymbol = game.secondarySymbol, size >= 28 {
                secondaryBadge(symbol: secondarySymbol)
            }

            if isCompleted {
                RoundedRectangle(cornerRadius: cornerRadius * 1.12, style: .continuous)
                    .strokeBorder(Theme.success, lineWidth: ringWidth)
                    .frame(width: size + ringInset, height: size + ringInset)
            }
        }
        .frame(width: size + ringInset, height: size + ringInset)
        .shadow(color: game.accent.opacity(0.3), radius: size * 0.1, y: size * 0.04)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(game.accessibilityName), \(isCompleted ? "completed" : "ready")")
    }

    private func secondaryBadge(symbol: String) -> some View {
        VStack {
            HStack {
                Spacer()
                Image(systemName: symbol)
                    .font(.system(size: secondarySize, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(size * 0.07)
                    .background(Circle().fill(game.accent))
                    .overlay(Circle().strokeBorder(.white.opacity(0.6), lineWidth: max(0.5, size * 0.02)))
            }
            Spacer()
        }
        .frame(width: size, height: size)
        .offset(x: size * 0.14, y: -size * 0.14)
    }
}

#Preview("Emblem grid") {
    ScrollView {
        VStack(spacing: 24) {
            ForEach([CGFloat(30), 36, 52], id: \.self) { size in
                VStack(spacing: 8) {
                    Text("Size \(Int(size))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 16) {
                        ForEach([BlipzGame.guess, .maths, .trivia], id: \.self) { game in
                            VStack(spacing: 6) {
                                BlipzGameEmblem(game: game, size: size, isCompleted: false)
                                BlipzGameEmblem(game: game, size: size, isCompleted: true)
                            }
                        }
                    }
                }
            }
        }
        .padding()
    }
    .background(Theme.background)
}

extension BlipzGame: Hashable {}
