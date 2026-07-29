import Foundation

struct MathsAnswersSubmit: Encodable {
    let answers: [Int]
}

struct MathSubmitResponse: Decodable {
    let userId: String
    let mathsScore: Int
    let correct: Int
    let total: Int
    let date: String
}
