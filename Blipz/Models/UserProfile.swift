import Foundation

struct UserProfile: Decodable {
    let id: String
    let username: String?
    let currentStreak: Int
    let longestStreak: Int
    let mathsScore: Int
    let triviaScore: Int
    let guessScore: Double
    let totalScore: Double
    let mathsCompleted: Bool
    let guessCompleted: Bool
    let triviaCompleted: Bool
}
