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
    private(set) var canPlay = false
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    var currentAnswerText = ""

    var totalCount: Int { problems.count }

    var currentProblem: MathProblem? {
        guard currentDisplayIndex < displayOrder.count else { return nil }
        return problems[displayOrder[currentDisplayIndex]]
    }

    func loadDailyContent() async {
        guard !isLoading else { return }
        isLoading = true
        canPlay = false
        errorMessage = nil
        defer { isLoading = false }
        do {
            let profile: UserProfile = try await APIClient.shared.get("users/me")
            if restoreCompletedResult(profile) { return }
            let content: DailyContent = try await APIClient.shared.get("games/daily-content")
            problems = content.mathProblems
            // Randomize presentation order per player; answers are still submitted
            // back in the server's original order (see submitAllAnswers).
            displayOrder = Array(problems.indices).shuffled()
            answers = Array(repeating: nil, count: problems.count)
            canPlay = result == nil
        } catch {
            errorMessage = "Couldn't load today's problems. \(error.friendlyMessage)"
        }
    }

    @discardableResult
    func restoreCompletedResult(_ profile: UserProfile) -> Bool {
        guard profile.mathsCompleted else { return false }
        canPlay = false
        problems = []
        displayOrder = []
        answers = []
        startDate = nil
        elapsedTime = profile.mathsElapsedSeconds
        phase = .finished
        result = MathSubmitResponse(userId: profile.id, mathsScore: profile.mathsScore,
            correct: profile.mathsScore, total: 20, date: BlipzDay.key(), alreadyCompleted: true)
        return true
    }

    func start() {
        guard canPlay, result == nil, phase == .notStarted, !problems.isEmpty else { return }
        phase = .playing
        startDate = Date()
    }

    func checkAnswer() {
        guard canPlay, result == nil, phase == .playing,
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
            canPlay = false
        } catch {
            errorMessage = "Couldn't submit your score. \(error.friendlyMessage)"
        }
        isLoading = false
    }
}
