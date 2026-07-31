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
    // maxPollAttempts counts total requests INCLUDING the original submission (not
    // retries after it). True worst-case wait: up to maxPollAttempts requests, each
    // taking up to the backend's own ~2s internal wait (games.py's
    // GUESS_WAIT_POLL_ATTEMPTS x GUESS_WAIT_POLL_INTERVAL_SECONDS = 4 x 0.5s) before it
    // falls back to 202, PLUS pollRetryDelay between each pair of attempts — i.e.
    // 5 x 2s + 4 x 1s = 14s worst case, bounded, never indefinite.
    private let maxPollAttempts = 5
    private let pollRetryDelay: Duration = .seconds(1)

    // Owns the in-flight submission so it can be cancelled from the View's lifecycle
    // (see cancelSubmission()) instead of leaking a background poll loop — and running
    // network activity — for up to ~14s after the user navigates away.
    private var submissionTask: Task<Void, Never>?

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
    //
    // Fire-and-forget entry point: owns the Task so it can be cancelled via
    // cancelSubmission() (call this from the View's .onDisappear) instead of the poll
    // loop running unobserved in the background after the user navigates away. `[weak
    // self]` means the task holds no strong reference to this view model either — it
    // cannot keep it alive past when SwiftUI would otherwise release it.
    func submit() {
        guard !guessText.isEmpty, !isLoading else { return }
        submissionTask = Task { [weak self] in
            await self?.performSubmit()
        }
    }

    func cancelSubmission() {
        submissionTask?.cancel()
    }

    private func performSubmit() async {
        let submittedGuess = guessText
        isLoading = true
        isScoring = false
        errorMessage = nil

        do {
            var attempt = 0
            pollLoop: while true {
                try Task.checkCancellation()

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
        } catch is CancellationError {
            // View disappeared mid-poll (see cancelSubmission()) — nothing left to
            // update; submittedGuess/guessText was never touched either way.
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
