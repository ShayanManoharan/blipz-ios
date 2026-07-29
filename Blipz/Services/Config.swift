import Foundation

enum Config {
    static let supabaseURL = URL(string: "https://eqivixkkpkkxijbgaegl.supabase.co")!
    // Publishable key — safe to embed on-device, this is what it's designed for.
    static let supabaseAnonKey = "sb_publishable_41Hnq1oKebcUdKwE0f_EgA_SMbrLiWo"
    // Simulator hitting a locally-run `uvicorn app.main:app --reload`.
    static let apiBaseURL = URL(string: "http://127.0.0.1:8000")!
}
