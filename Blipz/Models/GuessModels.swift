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
}

// Returned with HTTP 202 when another request is already scoring this attempt (see
// PRODUCTION_AUDIT.md B23) — the backend never calls OpenAI twice for the same
// user/day, so this just means "check back shortly," not an error.
struct GuessScoringInProgressResponse: Decodable {
    let status: String
    let detail: String
    let date: String
}
