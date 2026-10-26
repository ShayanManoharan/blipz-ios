import Foundation
import Observation

@Observable
final class TriviaGameViewModel {
    private(set) var questions: [TriviaQuestion] = []
    private(set) var currentIndex = 0
    private(set) var userAnswers: [TriviaAnswerSubmit] = []
    private(set) var result: TriviaSubmitResponse?
    private(set) var canPlay = false
    private(set) var review: [TriviaReviewQuestion]?
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    var currentQuestion: TriviaQuestion? {
        currentIndex < questions.count ? questions[currentIndex] : nil
    }

    var isFinished: Bool {
        !questions.isEmpty && currentIndex >= questions.count
    }

    func loadDailyContent() async {
        guard !isLoading else { return }
        isLoading = true
        canPlay = false
        errorMessage = nil
        defer { isLoading = false }
        do {
            let profile: UserProfile = try await APIClient.shared.get("users/me")
            if restoreCompletedResult(profile) {
                await loadReview()
                return
            }
            let content: DailyContent = try await APIClient.shared.get("games/daily-content")
            questions = content.triviaQuestions
            canPlay = result == nil
        } catch {
            errorMessage = "Couldn't load today's trivia. \(error.friendlyMessage)"
        }
    }

    @discardableResult
    func restoreCompletedResult(_ profile: UserProfile) -> Bool {
        guard profile.triviaCompleted else { return false }
        canPlay = false
        questions = []
        userAnswers = []
        currentIndex = 0
        result = TriviaSubmitResponse(userId: profile.id, triviaScore: profile.triviaScore,
            correct: profile.triviaScore, total: 5, date: BlipzDay.key(), alreadyCompleted: true)
        return true
    }

    // selectedOptionId must be the tapped option's stable identifier (A/B/C/D, from its
    // position in `options`), never the visible option text — see
    // PRODUCTION_AUDIT.md's Trivia grading fix.
    func selectAnswer(questionId: String, selectedOptionId: String) {
        guard canPlay, result == nil, !isLoading,
              currentQuestion?.id == questionId, triviaOptionIds.contains(selectedOptionId) else { return }
        userAnswers.append(TriviaAnswerSubmit(questionId: questionId, selectedOptionId: selectedOptionId))
        currentIndex += 1

        if isFinished {
            Task { await submitAllAnswers() }
        }
    }

    private func submitAllAnswers() async {
        isLoading = true
        do {
            let body = TriviaAnswersSubmit(answers: userAnswers)
            result = try await APIClient.shared.post("games/submit-trivia", body: body)
            canPlay = false
            await loadReview()
        } catch {
            errorMessage = "Couldn't submit your answers. \(error.friendlyMessage)"
        }
        isLoading = false
    }

    // Only ever succeeds once trivia is completed for today — the backend rejects
    // this with a 404 beforehand, since revealing correct answers pre-completion
    // would reopen the exact leak PRODUCTION_AUDIT.md B1 closed.
    private func loadReview() async {
        do {
            let response: TriviaReviewResponse = try await APIClient.shared.get("games/trivia-review")
            review = response.review
        } catch {
            review = nil
        }
    }
}
