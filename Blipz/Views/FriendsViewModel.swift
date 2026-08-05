import Foundation
import Observation

@Observable
final class FriendsViewModel {
    var usernameToAdd = ""
    private(set) var isLoading = false
    private(set) var errorMessage: String?
    private(set) var addSuccessMessage: String?

    func addFriend() async {
        guard !usernameToAdd.isEmpty else { return }
        isLoading = true
        errorMessage = nil
        addSuccessMessage = nil
        do {
            let body = AddFriendRequest(friendUsername: usernameToAdd)
            let response: AddFriendResponse = try await APIClient.shared.post("friends/add", body: body)
            addSuccessMessage = "Added \(response.username)!"
            usernameToAdd = ""
            Haptics.success()
        } catch {
            errorMessage = "Couldn't add that friend — check the username and try again."
            Haptics.error()
        }
        isLoading = false
    }
}
