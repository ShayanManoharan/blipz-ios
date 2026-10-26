import Foundation
import Observation

@MainActor @Observable
final class DailyRevealViewModel {
    private(set) var profile: UserProfile?
    private(set) var review: GuessReviewResponse?
    private(set) var imageURL: URL?
    private(set) var globalRank: Int?
    private(set) var friendsRank: Int?
    private(set) var isLoading = false
    private(set) var errorMessage: String?
    private(set) var promptUnavailable = false

    func load(for context: DailyRevealContext) async {
        isLoading = true
        errorMessage = nil
        profile = nil
        review = nil
        imageURL = nil
        globalRank = nil
        friendsRank = nil
        promptUnavailable = false
        defer { isLoading = false }
        do {
            let fresh: UserProfile = try await APIClient.shared.get("users/me")
            guard fresh.id == context.profile.id, context.date == BlipzDay.key() else {
                errorMessage = "This daily Blip has changed. Return to Today for your current games."
                return
            }
            guard fresh.dailyGamesComplete else {
                errorMessage = "Finish all three games to open your Daily Reveal."
                return
            }
            profile = fresh
        } catch {
            errorMessage = "Couldn’t verify your completed Blip. \(error.friendlyMessage)"
            return
        }

        // Both endpoints are existing, spoiler-safe reads. Check date identity before
        // displaying either so a UTC rollover cannot pair yesterday's prompt/score
        // with today's image. The backend owns package-revision resolution.
        if let daily: DailyContent = try? await APIClient.shared.get("games/daily-content"), daily.date == context.date {
            imageURL = URL(string: daily.imageUrl)
        }
        if let prompt: GuessReviewResponse = try? await APIClient.shared.get("games/guess-review"), prompt.date == context.date {
            review = prompt
        } else {
            promptUnavailable = true
        }
        if let username = profile?.username {
            if let global: GlobalLeaderboardResponse = try? await APIClient.shared.get("leaderboard/global"), global.date == context.date {
                globalRank = global.leaderboard.first { $0.username == username }?.rank
            }
            if let friends: FriendsLeaderboardResponse = try? await APIClient.shared.get("leaderboard/friends"), friends.date == context.date {
                friendsRank = friends.leaderboard.first { $0.username == username }?.rank
            }
        }
        // No percentile: the global endpoint is capped at 50, not the population.
        if context.date != BlipzDay.key() {
            profile = nil
            review = nil
            imageURL = nil
            globalRank = nil
            friendsRank = nil
            errorMessage = "A fresh daily Blip is here. Return to Today."
        }
    }
}
