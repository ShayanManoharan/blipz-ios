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
    var imageURL: URL? = nil

    var body: some View {
        ZStack {
            LinearGradient(colors: gradientColors, startPoint: .topLeading, endPoint: .bottomTrailing)
            Circle().fill(.white.opacity(0.13))
                .frame(width: size * 0.85).offset(x: -size * 0.22, y: -size * 0.28)
            symbol
            if game == .guess, let imageURL {
                AsyncImage(url: imageURL) { image in
                    image.resizable().scaledToFill()
                } placeholder: { Color.clear }
            }
        }
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: size * 0.22, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                    .strokeBorder(.white.opacity(0.22), lineWidth: 0.5)
            )
            .shadow(color: tint.opacity(0.16), radius: 5, y: 2)
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
            .foregroundStyle(.white)
        case .maths:
            ZStack {
                Circle().fill(Color.yellow.opacity(0.25)).frame(width: size * 0.65)
                Image(systemName: "lightbulb.fill")
                    .font(.system(size: size * 0.49, weight: .regular))
                    .foregroundStyle(Color(red: 1, green: 0.82, blue: 0.30))
                    .shadow(color: .yellow.opacity(0.5), radius: size * 0.09)
                Image(systemName: "sparkle").font(.system(size: size * 0.16))
                    .offset(x: size * 0.32, y: -size * 0.27)
                Image(systemName: "plus").font(.system(size: size * 0.15, weight: .medium))
                    .offset(x: -size * 0.32, y: size * 0.28)
            }.foregroundStyle(.white.opacity(0.85))
        case .trivia:
            ZStack {
                RoundedRectangle(cornerRadius: size * 0.12)
                    .fill(.white.opacity(0.14))
                    .frame(width: size * 0.76, height: size * 0.52)
                    .rotationEffect(.degrees(-12))
                Image(systemName: "questionmark")
                    .font(.system(size: size * 0.50, weight: .bold, design: .serif))
                    .rotationEffect(.degrees(-8))
                Image(systemName: "sparkle").font(.system(size: size * 0.17))
                    .offset(x: size * 0.31, y: -size * 0.28)
            }.foregroundStyle(.white)
        }
    }

    private var gradientColors: [Color] {
        switch game {
        case .guess: [Color(red: 0.20, green: 0.52, blue: 0.40), Theme.buttonFill]
        case .maths: [Color(red: 0.19, green: 0.63, blue: 0.58), Color(red: 0.04, green: 0.30, blue: 0.29)]
        case .trivia: [Color(red: 0.60, green: 0.42, blue: 0.81), Color(red: 0.27, green: 0.16, blue: 0.48)]
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
