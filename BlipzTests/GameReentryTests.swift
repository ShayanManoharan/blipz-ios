import Foundation
import Testing
@testable import Blipz

struct GameReentryTests {
    private func profile(mask: Int = 7) -> UserProfile {
        UserProfile(id: "unit-test-only", username: nil, currentStreak: 3, longestStreak: 5,
                    mathsScore: 20, triviaScore: 5, guessScore: 8.4, totalScore: 82.6,
                    mathsCompleted: mask & 2 != 0, guessCompleted: mask & 1 != 0,
                    triviaCompleted: mask & 4 != 0, mathsElapsedSeconds: 60)
    }

    @MainActor @Test func completedMathsRestoresWithoutPreparingOrStartingAnotherRound() {
        let model = MathGameViewModel()
        #expect(model.restoreCompletedResult(profile()))
        #expect(model.phase == .finished)
        #expect(model.result?.alreadyCompleted == true)
        #expect(model.result?.correct == 20)
        #expect(model.elapsedTime == 60)
        #expect(model.startDate == nil)
        #expect(model.problems.isEmpty && model.displayOrder.isEmpty)
        model.start()
        model.currentAnswerText = "5"
        model.checkAnswer()
        #expect(model.phase == .finished && model.startDate == nil)
        #expect(!model.canPlay && model.currentDisplayIndex == 0)
    }

    @MainActor @Test func completedTriviaRestoresAndCannotAcceptAnotherAnswer() {
        let model = TriviaGameViewModel()
        #expect(model.restoreCompletedResult(profile()))
        #expect(model.result?.alreadyCompleted == true)
        #expect(model.result?.correct == 5)
        model.selectAnswer(questionId: "q0", selectedOptionId: "A")
        #expect(!model.canPlay && model.questions.isEmpty)
        #expect(model.userAnswers.isEmpty && model.currentQuestion == nil)
    }

    @MainActor @Test func completedGuessRestoresProtectedReviewAndCannotSubmitAgain() {
        let model = GuessGameViewModel()
        let review = GuessReviewResponse(date: BlipzDay.key(), guess: "test-only guess",
                                        score: 8.4, actualPrompt: "test-only review")
        model.restoreCompletedResult(review, userId: "unit-test-only")
        model.guessText = "must not submit"
        model.submit()
        #expect(model.result?.alreadyCompleted == true)
        #expect(model.result?.guess == review.guess)
        #expect(model.result?.actualPrompt == review.actualPrompt)
        #expect(!model.canPlay && !model.isSubmitting)
    }

    @MainActor @Test func unverifiedEntryCannotStartAnyGame() {
        let maths = MathGameViewModel()
        maths.start()
        #expect(maths.phase == .notStarted && maths.startDate == nil)
        let guess = GuessGameViewModel()
        guess.guessText = "must wait for completion check"
        guess.submit()
        #expect(!guess.isSubmitting && guess.result == nil)
        let trivia = TriviaGameViewModel()
        trivia.selectAnswer(questionId: "q0", selectedOptionId: "A")
        #expect(trivia.userAnswers.isEmpty)
    }

    @MainActor @Test func incompleteProfilesAreNotRestoredAsCompleted() {
        let maths = MathGameViewModel()
        let trivia = TriviaGameViewModel()
        #expect(!maths.restoreCompletedResult(profile(mask: 0)))
        #expect(!trivia.restoreCompletedResult(profile(mask: 0)))
        #expect(maths.result == nil && maths.phase == .notStarted)
        #expect(trivia.result == nil)
    }
}
