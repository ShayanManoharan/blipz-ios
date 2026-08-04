import SwiftUI

struct RootView: View {
    @State private var auth = AuthManager.shared

    var body: some View {
        Group {
            if auth.isReady {
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
