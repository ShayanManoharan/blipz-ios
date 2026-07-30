import Foundation

struct TriviaAnswersSubmit: Encodable {
    let answers: [String]
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
    let selectedAnswer: String?
    let correctAnswer: String
    let isCorrect: Bool
}

struct TriviaReviewResponse: Decodable {
    let date: String
    let review: [TriviaReviewQuestion]
}
