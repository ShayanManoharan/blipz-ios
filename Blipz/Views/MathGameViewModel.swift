import Foundation
import Observation

@Observable
final class MathGameViewModel {
    enum Phase: Equatable {
        case notStarted
        case playing
        case finished
    }

    private(set) var problems: [MathProblem] = []
    private(set) var displayOrder: [Int] = []
    private var answers: [Int?] = []
    private(set) var currentDisplayIndex = 0
    private(set) var phase: Phase = .notStarted
    private(set) var startDate: Date?
    private(set) var elapsedTime: TimeInterval?
    private(set) var result: MathSubmitResponse?
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    var currentAnswerText = ""

    var totalCount: Int { problems.count }

    var currentProblem: MathProblem? {
        guard currentDisplayIndex < displayOrder.count else { return nil }
        return problems[displayOrder[currentDisplayIndex]]
    }

    func loadDailyContent() async {
        isLoading = true
        errorMessage = nil
        do {
            let content: DailyContent = try await APIClient.shared.get("games/daily-content")
            problems = content.mathProblems
            // Randomize presentation order per player; answers are still submitted
            // back in the server's original order (see submitAllAnswers).
            displayOrder = Array(problems.indices).shuffled()
            answers = Array(repeating: nil, count: problems.count)
        } catch {
            errorMessage = "Couldn't load today's problems. \(error.friendlyMessage)"
        }
        isLoading = false
    }

    func start() {
        phase = .playing
        startDate = Date()
    }

    func checkAnswer() {
        guard phase == .playing,
              let problem = currentProblem,
              let typed = Int(currentAnswerText),
              typed == problem.answer else { return }

        Haptics.light()
        answers[displayOrder[currentDisplayIndex]] = typed
        currentAnswerText = ""
        currentDisplayIndex += 1

        if currentDisplayIndex == displayOrder.count {
            elapsedTime = startDate.map { Date().timeIntervalSince($0) }
            phase = .finished
            Haptics.success()
            Task { await submitAllAnswers() }
        }
    }

    private func submitAllAnswers() async {
        isLoading = true
        do {
            let body = MathsAnswersSubmit(answers: answers.compactMap { $0 }, elapsedSeconds: elapsedTime ?? 0)
            result = try await APIClient.shared.post("games/submit-maths", body: body)
        } catch {
            errorMessage = "Couldn't submit your score. \(error.friendlyMessage)"
        }
        isLoading = false
    }
}
