import Foundation

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
