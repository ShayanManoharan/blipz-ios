import Foundation

struct UserProfile: Decodable {
    let id: String
    let username: String?
    let currentStreak: Int
    let longestStreak: Int
}
