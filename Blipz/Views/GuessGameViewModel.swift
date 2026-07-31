import Foundation
import Observation

@Observable
final class GuessGameViewModel {
    private(set) var imageUrl: URL?
    var guessText = ""
    private(set) var result: GuessSubmitResponse?
    private(set) var isLoading = false
    // True once the backend has told us another request is already scoring this
    // attempt (HTTP 202) and we're waiting it out — distinct from the brief
    // `isLoading` window of a normal single round trip, so the UI can say "this is
    // taking a bit longer than usual" instead of just showing the same spinner text.
    private(set) var isScoring = false
    private(set) var errorMessage: String?

    // Bounded client-side polling: re-submitting the SAME guess text is safe and
    // idempotent (see PRODUCTION_AUDIT.md B23) — the backend never calls OpenAI again
    // once a scoring attempt is in flight or completed, it just tells us to check back.
    // Combined with the backend's own ~2s internal wait per call, this gives roughly
    // 5 x 2s = 10s of total patience before giving up — bounded, never indefinite.
    private let maxPollAttempts = 5
    private let pollRetryDelay: Duration = .seconds(1)

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

    // guard !isLoading prevents a repeated tap from firing a second submission while
    // one is already in flight — the button is also hidden during isLoading (see
    // GuessGameView), this is the model-level backstop for that.
    func submitGuess() async {
        guard !guessText.isEmpty, !isLoading else { return }
        let submittedGuess = guessText
        isLoading = true
        isScoring = false
        errorMessage = nil

        do {
            var attempt = 0
            pollLoop: while true {
                let (statusCode, data) = try await APIClient.shared.postRaw(
                    "games/submit-guess", body: GuessSubmit(guess: submittedGuess)
                )

                switch statusCode {
                case 202:
                    isScoring = true
                    attempt += 1
                    if attempt >= maxPollAttempts {
                        errorMessage = "Still scoring your guess — tap Lock In My Guess again in a moment."
                        break pollLoop
                    }
                    try await Task.sleep(for: pollRetryDelay)
                default:
                    result = try APIClient.shared.decode(GuessSubmitResponse.self, from: data)
                    break pollLoop
                }
            }
        } catch {
            // submittedGuess/guessText is intentionally left untouched here — a timeout
            // or transient error must not lose what the user typed; they can just tap
            // submit again.
            errorMessage = "Failed to submit guess: \(error.localizedDescription)"
        }

        isScoring = false
        isLoading = false
    }
}
