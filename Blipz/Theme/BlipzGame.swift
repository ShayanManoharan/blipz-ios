import SwiftUI

enum BlipzGame: Hashable {
    case guess
    case maths
    case trivia

    /// Fixed daily order — Guess is always "game 1 of 3" and so on, independent of
    /// which order the player actually completes them in.
    static let orderedDaily: [BlipzGame] = [.guess, .maths, .trivia]

    /// The next not-yet-played game after this one, in fixed order — drives each
    /// game's result screen chaining into the next unplayed game (nil once the day's
    /// last game is done, so the caller can show "See today's score" instead).
    func nextUnplayed(in profile: UserProfile) -> BlipzGame? {
        guard let index = Self.orderedDaily.firstIndex(of: self) else { return nil }
        return Self.orderedDaily[(index + 1)...].first { !profile.isCompleted($0) }
    }
}

extension UserProfile {
    func isCompleted(_ game: BlipzGame) -> Bool {
        switch game {
        case .guess: return guessCompleted
        case .maths: return mathsCompleted
        case .trivia: return triviaCompleted
        }
    }
}

struct BlipzGameEmblem: View {
    let game: BlipzGame
    var size: CGFloat = 40

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.26, style: .continuous)
            .fill(surface)
            .frame(width: size, height: size)
            .overlay(symbol)
            .overlay(
                RoundedRectangle(cornerRadius: size * 0.26, style: .continuous)
                    .strokeBorder(tint.opacity(0.10), lineWidth: 0.5)
            )
            .shadow(color: tint.opacity(0.08), radius: 4, y: 2)
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private var symbol: some View {
        switch game {
        case .guess:
            ZStack(alignment: .topTrailing) {
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: size * 0.39, weight: .semibold))
                Image(systemName: "sparkle")
                    .font(.system(size: size * 0.18, weight: .bold))
                    .offset(x: size * 0.09, y: -size * 0.08)
            }
            .foregroundStyle(tint)
        case .maths:
            Image(systemName: "plus.forwardslash.minus")
                .font(.system(size: size * 0.40, weight: .semibold))
                .foregroundStyle(tint)
        case .trivia:
            Image(systemName: "questionmark.bubble.fill")
                .font(.system(size: size * 0.40, weight: .semibold))
                .foregroundStyle(tint)
        }
    }

    private var surface: Color {
        switch game {
        case .guess: Theme.guessSurface
        case .maths: Theme.mathsSurface
        case .trivia: Theme.triviaSurface
        }
    }

    private var tint: Color {
        switch game {
        case .guess: Theme.accent
        case .maths: Theme.mathsAccent
        case .trivia: Theme.triviaAccent
        }
    }
}

struct BlipzSymbolTile: View {
    let symbol: String
    var tint: Color = Theme.accent
    var size: CGFloat = 30

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.32, style: .continuous)
            .fill(Theme.symbolSurface)
            .frame(width: size, height: size)
            .overlay(
                Image(systemName: symbol)
                    .font(.system(size: size * 0.43, weight: .medium))
                    .foregroundStyle(tint)
            )
            .accessibilityHidden(true)
    }
}

struct BlipzAvatar: View {
    let name: String
    var size: CGFloat = 36

    var body: some View {
        Circle()
            .fill(Theme.avatarSurface)
            .overlay(
                Text(initial)
                    .font(.system(size: size * 0.42, weight: .bold))
                    .foregroundStyle(Theme.accent)
            )
            .overlay(Circle().strokeBorder(Theme.accent.opacity(0.08), lineWidth: 0.5))
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }

    private var initial: String {
        guard let first = name.trimmingCharacters(in: .whitespaces).first else { return "?" }
        return String(first).uppercased()
    }
}
