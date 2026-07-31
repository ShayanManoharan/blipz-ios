import Foundation

// Never the visible option text — see PRODUCTION_AUDIT.md's Trivia grading fix. The
// backend rejects anything outside A-D at the schema layer.
struct TriviaAnswerSubmit: Encodable {
    let questionId: String
    let selectedOptionId: String
}

struct TriviaAnswersSubmit: Encodable {
    let answers: [TriviaAnswerSubmit]
}

struct TriviaSubmitResponse: Decodable {
    let userId: String
    let triviaScore: Int
    let correct: Int
    let total: Int
    let date: String
    let alreadyCompleted: Bool
}

struct TriviaReviewQuestion: Decodable {
    let question: String
    let options: [String]
    let selectedOptionId: String?
    let selectedAnswerText: String?
    let correctOptionId: String
    let correctAnswerText: String
    let isCorrect: Bool
}

struct TriviaReviewResponse: Decodable {
    let date: String
    let review: [TriviaReviewQuestion]
}
