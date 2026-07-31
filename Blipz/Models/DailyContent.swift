import Foundation

struct DailyContent: Decodable {
    let id: String
    let date: String
    let imageUrl: String
    let triviaQuestions: [TriviaQuestion]
    let mathProblems: [MathProblem]
}

// Intentionally no `answer`/`correctOptionId` field — the backend never sends it.
// Trivia correctness is graded server-side by POST /games/submit-trivia; the client
// only learns the aggregate correct/total after submitting, never per-question, before
// or during play.
//
// `id` is stable for this day's content only (not globally unique across days) — it
// exists so the client can tag each answer with the question it belongs to instead of
// relying on submission order. `options` stay plain display text; each option's stable
// identifier is its position mapped through `triviaOptionIds` (A/B/C/D), not the text
// itself — see PRODUCTION_AUDIT.md's Trivia grading fix for why conflating the two was
// the root cause of the original bug.
struct TriviaQuestion: Decodable {
    let id: String
    let question: String
    let category: String
    let options: [String]
}

let triviaOptionIds = ["A", "B", "C", "D"]
