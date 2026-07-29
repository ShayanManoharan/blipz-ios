import Foundation
import Supabase
import Observation

@Observable
final class AuthManager {
    static let shared = AuthManager()

    let client: SupabaseClient
    private(set) var userId: String?
    private(set) var isReady = false

    private init() {
        client = SupabaseClient(supabaseURL: Config.supabaseURL, supabaseKey: Config.supabaseAnonKey)
    }

    /// Restores an existing session, or signs in anonymously if there isn't one.
    /// Call once at app launch, before showing any game content.
    func signInIfNeeded() async {
        if let session = try? await client.auth.session {
            userId = session.user.id.uuidString
        } else if let session = try? await client.auth.signInAnonymously() {
            userId = session.user.id.uuidString
        } else {
            print("Blipz: anonymous sign-in failed")
        }
        isReady = true
    }

    /// Fetched fresh on every call (not cached) since anonymous tokens expire/rotate.
    func currentAccessToken() async throws -> String {
        try await client.auth.session.accessToken
    }
}
