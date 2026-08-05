import Foundation

struct GuessSubmit: Encodable {
    let guess: String
}

struct GuessSubmitResponse: Decodable {
    let userId: String
    let guess: String
    let score: Double
    let date: String
    let alreadyCompleted: Bool
    // Only ever populated once guess_completed is already true for today — the
    // backend never reveals this beforehand (see PRODUCTION_AUDIT.md's Guess
    // spoiler-safety rule). Optional purely as a decode safety net; the backend
    // always sends a value on this response shape.
    let actualPrompt: String?
}

// Mirrors GET /games/trivia-review — only resolves once guess_completed is true for
// today; used to restore the result screen if GuessGameView is reopened after the
// day's Guess is already done (rather than showing the play composer again).
struct GuessReviewResponse: Decodable {
    let date: String
    let guess: String
    let score: Double
    let actualPrompt: String
}

// Returned with HTTP 202 when another request is already scoring this attempt (see
// PRODUCTION_AUDIT.md B23) — the backend never calls OpenAI twice for the same
// user/day, so this just means "check back shortly," not an error.
struct GuessScoringInProgressResponse: Decodable {
    let status: String
    let detail: String
    let date: String
}
