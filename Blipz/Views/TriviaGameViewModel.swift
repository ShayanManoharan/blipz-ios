import Foundation
import Observation

@Observable
final class TriviaGameViewModel {
    private(set) var questions: [TriviaQuestion] = []
    private(set) var currentIndex = 0
    private(set) var userAnswers: [String] = []
    private(set) var result: TriviaSubmitResponse?
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    var currentQuestion: TriviaQuestion? {
        currentIndex < questions.count ? questions[currentIndex] : nil
    }

    var isFinished: Bool {
        !questions.isEmpty && currentIndex >= questions.count
    }

    func loadDailyContent() async {
        isLoading = true
        errorMessage = nil
        do {
            let content: DailyContent = try await APIClient.shared.get("games/daily-content")
            questions = content.triviaQuestions
        } catch {
            errorMessage = "No daily content available yet. Generate it on the backend first."
        }
        isLoading = false
    }

    func selectAnswer(_ answer: String) {
        userAnswers.append(answer)
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
        } catch {
            errorMessage = "Failed to submit answers: \(error.localizedDescription)"
        }
        isLoading = false
    }
}
