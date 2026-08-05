import Foundation

struct HistoryDay: Decodable {
    let date: String
    let totalScore: Double
}

struct HistoryResponse: Decodable {
    let history: [HistoryDay]
}
