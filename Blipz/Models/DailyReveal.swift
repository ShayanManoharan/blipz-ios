import Foundation

extension UserProfile {
    var dailyGamesComplete: Bool { guessCompleted && mathsCompleted && triviaCompleted }
}

/// Presentation only. The backend remains authoritative for the total and maths
/// timing curve. Deriving maths from the stored total avoids a second scoring engine
/// on the client, and preserves the backend's one-decimal rounding in the breakdown.
struct DailyScoreBreakdown {
    let guess: Double
    let maths: Double
    let trivia: Double

    init?(profile: UserProfile) {
        guard profile.dailyGamesComplete,
              profile.guessScore.isFinite, (0...10).contains(profile.guessScore),
              (0...5).contains(profile.triviaScore),
              profile.totalScore.isFinite, (0...100).contains(profile.totalScore) else { return nil }
        guess = (profile.guessScore * 4 * 10).rounded() / 10
        trivia = Double(profile.triviaScore) * 6
        maths = ((profile.totalScore - guess - trivia) * 10).rounded() / 10
        guard (0...30).contains(maths) else { return nil }
    }
}

enum DailyRevealEligibility {
    static func canReveal(profile: UserProfile, date: String, currentDate: String = BlipzDay.key()) -> Bool {
        date == currentDate && profile.dailyGamesComplete
    }
}
