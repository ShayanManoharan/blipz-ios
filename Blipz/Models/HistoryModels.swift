import Foundation

struct HistoryDay: Decodable {
    let date: String
    let totalScore: Double
    let mathsElapsedSeconds: Double?
}

struct HistoryResponse: Decodable {
    let history: [HistoryDay]
}
