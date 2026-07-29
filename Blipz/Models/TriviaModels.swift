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
}
