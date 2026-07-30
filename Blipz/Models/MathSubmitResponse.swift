import Foundation

struct MathsAnswersSubmit: Encodable {
    let answers: [Int]
    let elapsedSeconds: Double
}

struct MathSubmitResponse: Decodable {
    let userId: String
    let mathsScore: Int
    let correct: Int
    let total: Int
    let date: String
    let alreadyCompleted: Bool
}
