import Foundation
import Observation

@Observable
final class GuessGameViewModel {
    private(set) var imageUrl: URL?
    var guessText = ""
    private(set) var result: GuessSubmitResponse?
    private(set) var actualPrompt: String?
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    func loadDailyContent() async {
        isLoading = true
        errorMessage = nil
        do {
            let content: DailyContent = try await APIClient.shared.get("games/daily-content")
            imageUrl = URL(string: content.imageUrl)
        } catch {
            errorMessage = "No daily content available yet. Generate it on the backend first."
        }
        isLoading = false
    }

    func submitGuess() async {
        guard !guessText.isEmpty else { return }
        isLoading = true
        errorMessage = nil
        do {
            let body = GuessSubmit(guess: guessText)
            result = try await APIClient.shared.post("games/submit-guess", body: body)
        } catch {
            errorMessage = "Failed to submit guess: \(error.localizedDescription)"
        }
        isLoading = false
    }
}
