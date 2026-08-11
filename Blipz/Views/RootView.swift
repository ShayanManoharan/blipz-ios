import SwiftUI

struct RootView: View {
    @State private var auth = AuthManager.shared
    // Global, not per-user — deliberately not keyed to the anonymous auth id, so it
    // survives a signed-out/re-signed-in session and only resets on a real reinstall.
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    var body: some View {
        Group {
            if !hasCompletedOnboarding {
                // Shown before auth resolves — no backend dependency, so a new player
                // sees this instantly instead of waiting on sign-in first.
                OnboardingView { hasCompletedOnboarding = true }
            } else if auth.isReady {
                MainTabView()
            } else if auth.signInFailed {
                signInFailedView
            } else {
                ProgressView("Signing in…")
            }
        }
        .task {
            await auth.signInIfNeeded()
        }
    }

    private var signInFailedView: some View {
        VStack(spacing: 16) {
            Image(systemName: "wifi.exclamationmark")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("Couldn't sign you in")
                .font(.headline)
            Text("Check your connection and try again.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Try Again") {
                Task { await auth.signInIfNeeded() }
            }
            .buttonStyle(PrimaryButtonStyle())
        }
        .padding()
        .screenBackground()
    }
}

#Preview {
    RootView()
}
