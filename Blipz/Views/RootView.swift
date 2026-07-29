import SwiftUI

struct RootView: View {
    @State private var auth = AuthManager.shared

    var body: some View {
        Group {
            if auth.isReady {
                MathGameView()
            } else {
                ProgressView("Signing in…")
            }
        }
        .task {
            await auth.signInIfNeeded()
        }
    }
}

#Preview {
    RootView()
}
