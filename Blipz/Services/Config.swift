import Foundation

// Environment-aware configuration — values come from the active build configuration's
// .xcconfig (Blipz/Configs/{Debug,Staging,Release}.xcconfig) via Info.plist injection
// (GENERATE_INFOPLIST_FILE=YES + INFOPLIST_KEY_* build settings). See
// docs/DEPLOYMENT.md §2/§7 for the full environment strategy and the one-time Xcode
// wiring step these xcconfig files still need (attaching them to their build
// configuration, and adding the Staging configuration itself, is a project-settings
// change too risky to script blindly — see that doc for exact steps).
//
// Supabase's URL/anon key are not secrets (designed to be embedded on-device) and are
// identical across environments today, so they fall back to the existing known-good
// values if the xcconfig hasn't been wired up yet — this is a value-consistency
// convenience, not a security boundary. OpenAI's key and Supabase's service-role key
// are backend-only and never appear anywhere in this app.
enum Config {
    static let supabaseURL = infoPlistURL(key: "SupabaseURL")
        ?? URL(string: "https://eqivixkkpkkxijbgaegl.supabase.co")!
    static let supabaseAnonKey = infoPlistString(key: "SupabaseAnonKey")
        ?? "sb_publishable_41Hnq1oKebcUdKwE0f_EgA_SMbrLiWo"

    static let apiBaseURL: URL = {
        #if DEBUG
        // Falls back to local dev even before Configs/Debug.xcconfig is attached to
        // the Debug build configuration — local development must never be broken by
        // this change. Once attached, this reads the identical value from there.
        return infoPlistURL(key: "APIBaseURL") ?? URL(string: "http://127.0.0.1:8000")!
        #else
        // Staging/Release have no safe fallback: a missing, placeholder, or
        // accidentally-local URL must fail loudly at launch rather than silently
        // shipping broken or pointing at a developer's Mac.
        guard let value = infoPlistString(key: "APIBaseURL"), !value.isEmpty else {
            fatalError(
                "Missing required Info.plist key 'APIBaseURL' — attach this build "
                    + "configuration's .xcconfig (see Blipz/Configs/) before building. "
                    + "See docs/DEPLOYMENT.md §7."
            )
        }
        guard !value.hasPrefix("REPLACE_WITH_") else {
            fatalError(
                "APIBaseURL is still the placeholder '\(value)' — set the real backend "
                    + "URL in the active .xcconfig before shipping this build "
                    + "configuration. See docs/DEPLOYMENT.md §5/§7."
            )
        }
        guard let url = URL(string: value) else {
            fatalError("APIBaseURL is not a valid URL: '\(value)'")
        }
        guard url.host != "127.0.0.1", url.host != "localhost" else {
            fatalError(
                "APIBaseURL ('\(value)') points at localhost in a non-Debug build — "
                    + "this build configuration must point at a real hosted backend."
            )
        }
        return url
        #endif
    }()

    private static func infoPlistString(key: String) -> String? {
        Bundle.main.object(forInfoDictionaryKey: key) as? String
    }

    private static func infoPlistURL(key: String) -> URL? {
        infoPlistString(key: key).flatMap { URL(string: $0) }
    }
}
