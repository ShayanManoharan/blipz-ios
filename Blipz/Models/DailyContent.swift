import Foundation

struct DailyContent: Decodable {
    let id: String
    let date: String
    let imageUrl: String
    let imagePrompt: String
    let triviaQuestions: [TriviaQuestion]
    let mathProblems: [MathProblem]
}

struct TriviaQuestion: Decodable {
    let question: String
    let category: String
    let options: [String]
    let answer: String
}
