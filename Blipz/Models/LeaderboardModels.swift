import Foundation

struct LeaderboardEntry: Decodable, Identifiable {
    var id: Int { rank }
    let rank: Int
    let username: String
    let totalScore: Double
    let guessScore: Double
    let mathsScore: Int
    let triviaScore: Int
}

struct GlobalLeaderboardResponse: Decodable {
    let date: String
    let message: String
    let averageGuessScore: Double
    let leaderboard: [LeaderboardEntry]
}

struct FriendsLeaderboardResponse: Decodable {
    let date: String
    let leaderboard: [LeaderboardEntry]
}
