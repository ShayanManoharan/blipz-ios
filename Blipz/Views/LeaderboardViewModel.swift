import Foundation
import Observation

@Observable
final class LeaderboardViewModel {
    private(set) var globalEntries: [LeaderboardEntry] = []
    private(set) var friendsEntries: [LeaderboardEntry] = []
    private(set) var dailyMessage: String?
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    func loadGlobal() async {
        isLoading = true
        errorMessage = nil
        do {
            let response: GlobalLeaderboardResponse = try await APIClient.shared.get("leaderboard/global")
            globalEntries = response.leaderboard
            dailyMessage = response.message
        } catch {
            errorMessage = "Couldn't load the global leaderboard."
        }
        isLoading = false
    }

    func loadFriends() async {
        isLoading = true
        errorMessage = nil
        do {
            let response: FriendsLeaderboardResponse = try await APIClient.shared.get("leaderboard/friends")
            friendsEntries = response.leaderboard
        } catch {
            errorMessage = "Couldn't load the friends leaderboard."
        }
        isLoading = false
    }
}
