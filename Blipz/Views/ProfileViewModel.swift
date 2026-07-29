import Foundation
import Observation

@Observable
final class ProfileViewModel {
    private(set) var profile: UserProfile?

    func loadProfile() async {
        profile = try? await APIClient.shared.get("users/me")
    }
}
