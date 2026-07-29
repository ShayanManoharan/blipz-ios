import Foundation
import Observation

@Observable
final class MathGameViewModel {
    private(set) var problems: [MathProblem] = []
    private(set) var currentIndex = 0
    private(set) var userAnswers: [Int] = []
    private(set) var result: MathSubmitResponse?
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    var currentAnswerText = ""

    var currentProblem: MathProblem? {
        currentIndex < problems.count ? problems[currentIndex] : nil
    }

    var isFinished: Bool {
        !problems.isEmpty && currentIndex >= problems.count
    }

    func loadDailyContent() async {
        isLoading = true
        errorMessage = nil
        do {
            let content: DailyContent = try await APIClient.shared.get("games/daily-content")
            problems = content.mathProblems
        } catch {
            errorMessage = "No daily content available yet. Generate it on the backend first."
        }
        isLoading = false
    }

    func submitCurrentAnswer() {
        guard let answer = Int(currentAnswerText) else { return }
        userAnswers.append(answer)
        currentAnswerText = ""
        currentIndex += 1

        if isFinished {
            Task { await submitAllAnswers() }
        }
    }

    private func submitAllAnswers() async {
        isLoading = true
        do {
            let body = MathsAnswersSubmit(answers: userAnswers)
            result = try await APIClient.shared.post("games/submit-maths", body: body)
        } catch {
            errorMessage = "Failed to submit score: \(error.localizedDescription)"
        }
        isLoading = false
    }
}
