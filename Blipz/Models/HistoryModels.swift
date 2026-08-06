import Foundation

struct HistoryDay: Decodable {
    let date: String
    let totalScore: Double
    let mathsElapsedSeconds: Double?
    // "legacy_raw_35" (unweighted raw-count sum, max 35) or "normalized_100" — derived
    // server-side from this row's own date against the scoring cutover, never stored.
    // The two scales are never directly comparable — see YouView's isLegacyScoring.
    let scoringModel: String
}

struct HistoryResponse: Decodable {
    let history: [HistoryDay]
}
