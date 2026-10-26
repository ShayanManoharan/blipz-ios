import Foundation
import Testing
@testable import Blipz

// Synthetic values are confined to unit tests. No screenshot/production fixture
// mode, backend write, real attempt submission, or example leaderboard is installed.
struct BlipzTests {
    private func profile(mask: Int = 7, guess: Double = 8.4, trivia: Int = 5, total: Double = 82.6) -> UserProfile {
        UserProfile(id: "unit-test-only", username: nil, currentStreak: 1, longestStreak: 1,
                    mathsScore: 20, triviaScore: trivia, guessScore: guess, totalScore: total,
                    mathsCompleted: mask & 2 != 0, guessCompleted: mask & 1 != 0,
                    triviaCompleted: mask & 4 != 0, mathsElapsedSeconds: 60)
    }

    @Test(arguments: Array(0...7))
    func revealRequiresAllThreeFlags(mask: Int) {
        #expect(DailyRevealEligibility.canReveal(profile: profile(mask: mask), date: "2026-10-03", currentDate: "2026-10-03") == (mask == 7))
    }

    @Test func completionIsNotInferredFromScore() {
        #expect(DailyRevealEligibility.canReveal(profile: profile(total: 0), date: "2026-10-03", currentDate: "2026-10-03"))
        #expect(!DailyRevealEligibility.canReveal(profile: profile(mask: 0, total: 100), date: "2026-10-03", currentDate: "2026-10-03"))
    }

    @Test func priorDayCannotReveal() {
        #expect(!DailyRevealEligibility.canReveal(profile: profile(), date: "2026-10-02", currentDate: "2026-10-03"))
    }

    @Test(arguments: [(10.0, 5, 100.0, 30.0), (8.4, 5, 82.6, 19.0), (7.1, 4, 82.4, 30.0), (0.0, 0, 3.0, 3.0), (8.44, 5, 82.8, 19.0)])
    func displayedBreakdownPreservesAuthoritativeTotal(values: (Double, Int, Double, Double)) throws {
        let breakdown = try #require(DailyScoreBreakdown(profile: profile(guess: values.0, trivia: values.1, total: values.2)))
        #expect(abs(breakdown.maths - values.3) < 0.001)
        #expect(abs(breakdown.guess + breakdown.maths + breakdown.trivia - values.2) < 0.001)
    }

    @Test func invalidOrIncompleteBreakdownIsOmitted() {
        #expect(DailyScoreBreakdown(profile: profile(mask: 3)) == nil)
        #expect(DailyScoreBreakdown(profile: profile(guess: 10, total: 10)) == nil)
        #expect(DailyScoreBreakdown(profile: profile(guess: .nan)) == nil)
        #expect(DailyScoreBreakdown(profile: profile(total: .infinity)) == nil)
        #expect(DailyScoreBreakdown(profile: profile(trivia: 6)) == nil)
    }

    @MainActor @Test(arguments: [(BlipzGame.guess, 1, BlipzGame.maths), (.maths, 2, .trivia), (.trivia, 4, .guess), (.maths, 6, .guess), (.guess, 5, .maths)])
    func nextGameFindsEarlierUnplayedGames(values: (BlipzGame, Int, BlipzGame)) {
        let matches = values.0.nextUnplayed(in: profile(mask: values.1)) == values.2
        #expect(matches)
    }

    @Test func completedDayHasNoNextGame() {
        for game in BlipzGame.orderedDaily { #expect(game.nextUnplayed(in: profile()) == nil) }
    }

    @Test func competitiveDateUsesUTC() throws {
        let date = try #require(ISO8601DateFormatter().date(from: "2026-10-03T00:30:00Z"))
        #expect(BlipzDay.key(for: date) == "2026-10-03")
        #expect(BlipzDay.calendar.timeZone.secondsFromGMT() == 0)
    }

    @MainActor @Test func automaticRevealIsOncePerUserDayButCanBeReopened() async {
        let coordinator = DailyRevealCoordinator()
        await coordinator.presentAfterCompletion(profile: profile(), date: BlipzDay.key(), alreadyCompleted: false, reduceMotion: true)
        #expect(coordinator.presentation != nil)
        coordinator.presentation = nil
        await coordinator.presentAfterCompletion(profile: profile(), date: BlipzDay.key(), alreadyCompleted: false, reduceMotion: true)
        #expect(coordinator.presentation == nil)
        coordinator.show(profile: profile())
        #expect(coordinator.presentation != nil)
    }

    @MainActor @Test func restoringCompletedGameDoesNotAutoReveal() async {
        let coordinator = DailyRevealCoordinator()
        await coordinator.presentAfterCompletion(profile: profile(), date: BlipzDay.key(), alreadyCompleted: true, reduceMotion: true)
        #expect(coordinator.presentation == nil)
        coordinator.show(profile: profile(mask: 3))
        #expect(coordinator.presentation == nil)
    }
}
