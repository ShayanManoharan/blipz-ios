import Foundation

struct DailyContent: Decodable {
    let id: String
    let date: String
    let imageUrl: String
    let triviaQuestions: [TriviaQuestion]
    let mathProblems: [MathProblem]
}

// Intentionally no `answer` field — the backend never sends it. Trivia correctness is
// graded server-side by POST /games/submit-trivia; the client only learns the aggregate
// correct/total after submitting, never per-question, before or during play.
struct TriviaQuestion: Decodable {
    let question: String
    let category: String
    let options: [String]
}
