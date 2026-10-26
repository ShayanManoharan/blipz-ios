import SwiftUI
import Observation

struct DailyRevealContext: Identifiable {
    let profile: UserProfile
    let date: String
    var id: String { "\(profile.id):\(date)" }
}

/// UI-only coordination. Never submits attempts, updates streaks, or writes scores.
@MainActor @Observable
final class DailyRevealCoordinator {
    static let shared = DailyRevealCoordinator()
    var presentation: DailyRevealContext?
    private var automaticallyShown: Set<String> = []

    func presentAfterCompletion(profile: UserProfile, date: String, alreadyCompleted: Bool, reduceMotion: Bool) async {
        let context = DailyRevealContext(profile: profile, date: date)
        guard !alreadyCompleted,
              DailyRevealEligibility.canReveal(profile: profile, date: date),
              !automaticallyShown.contains(context.id), presentation == nil else { return }
        if !reduceMotion {
            do { try await Task.sleep(for: .milliseconds(350)) }
            catch { return }
        }
        guard !Task.isCancelled, presentation == nil,
              DailyRevealEligibility.canReveal(profile: profile, date: date),
              !automaticallyShown.contains(context.id) else { return }
        automaticallyShown.insert(context.id)
        presentation = context
    }

    func show(profile: UserProfile, date: String? = nil) {
        let date = date ?? BlipzDay.key()
        guard DailyRevealEligibility.canReveal(profile: profile, date: date) else { return }
        presentation = DailyRevealContext(profile: profile, date: date)
    }

    func backToToday() {
        TabRouter.shared.todayPath.removeAll()
        TabRouter.shared.selected = .today
        presentation = nil
    }
}

struct DailyGameNextAction: View {
    let game: BlipzGame
    let profile: UserProfile?
    let errorMessage: String?
    let retry: () -> Void

    var body: some View {
        if errorMessage != nil {
            Button("Refresh daily result", action: retry).buttonStyle(PrimaryButtonStyle())
        } else if let profile {
            if let next = game.nextUnplayed(in: profile) {
                NavigationLink(value: next) { Text("Next: \(next.title)") }
                    .buttonStyle(PrimaryButtonStyle())
            } else if profile.dailyGamesComplete {
                Button("See Daily Reveal") { DailyRevealCoordinator.shared.show(profile: profile) }
                    .buttonStyle(PrimaryButtonStyle())
            }
        } else {
            ProgressView("Refreshing your result…").frame(maxWidth: .infinity)
        }
    }
}
