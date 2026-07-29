import Foundation
import Observation

@Observable
final class ProfileViewModel {
    private(set) var profile: UserProfile?
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    func loadProfile() async {
        isLoading = true
        errorMessage = nil
        do {
            profile = try await APIClient.shared.get("users/me")
        } catch {
            errorMessage = "Couldn't load profile."
        }
        isLoading = false
    }
}
