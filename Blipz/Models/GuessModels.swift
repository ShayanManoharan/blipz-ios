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
