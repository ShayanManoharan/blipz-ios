import SwiftUI

struct YouView: View {
    @State private var viewModel = ProfileViewModel()
    @State private var history: [HistoryDay] = []
    @State private var showingOnboarding = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    titleRow

                    if let profile = viewModel.profile {
                        identityRow(profile)
                        statsRow(profile)
                        historySection
                        reminderRow
                        howBlipzWorksRow
                    } else if let error = viewModel.errorMessage {
                        Text(error)
                            .foregroundStyle(Theme.error)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                            .padding(.top, 40)
                            .frame(maxWidth: .infinity)
                    } else if viewModel.isLoading {
                        ProgressView()
                            .accessibilityLabel("Loading profile")
                            .frame(maxWidth: .infinity)
                            .padding(.top, 60)
                    }
                }
            }
            .screenBackground()
            .toolbar(.hidden, for: .navigationBar)
            .task {
                await viewModel.loadProfile()
                await loadHistory()
            }
            .sheet(isPresented: $showingOnboarding) {
                OnboardingView { showingOnboarding = false }
            }
        }
    }

    private func loadHistory() async {
        do {
            let response: HistoryResponse = try await APIClient.shared.get("users/me/history")
            history = response.history
        } catch {
            history = []
        }
    }

    // MARK: - Title
    //
    // "Settings ›" is a static placeholder — there's no Settings screen in the app yet.

    private var titleRow: some View {
        HStack {
            Text("You")
                .font(.system(size: 28, weight: .bold))
            Spacer()
            Text("Settings ›")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 18)
        .padding(.top, 14)
        .padding(.bottom, 12)
    }

    // MARK: - Identity
    //
    // "Pick a username ›" is a static placeholder — there's no username-setting
    // endpoint yet, so it can't actually do anything if tapped.

    private func identityRow(_ profile: UserProfile) -> some View {
        HStack(spacing: 14) {
            Circle()
                .fill(Theme.accent.opacity(0.15))
                .frame(width: 48, height: 48)
                .overlay(
                    Text(initial(displayName(profile)))
                        .font(.title3.weight(.bold))
                        .foregroundStyle(Theme.accent)
                )
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(displayName(profile))
                    .font(.title3.weight(.medium))
                Text("Pick a username ›")
                    .font(.caption)
                    .foregroundStyle(Theme.accent)
            }
            Spacer()
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 16)
    }

    private func displayName(_ profile: UserProfile) -> String {
        profile.username ?? "guest_\(profile.id.prefix(8))"
    }

    private func initial(_ name: String) -> String {
        guard let first = name.trimmingCharacters(in: .whitespaces).first else { return "?" }
        return String(first).uppercased()
    }

    // MARK: - Stats

    private func statsRow(_ profile: UserProfile) -> some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 0) {
                statTile(value: "\(profile.currentStreak)", label: "streak")
                Divider().frame(height: 40)
                statTile(value: "\(profile.longestStreak)", label: "best")
                Divider().frame(height: 40)
                statTile(value: profile.totalScore.formatted(.number.precision(.fractionLength(1))), label: "today")
            }
            Divider()
        }
    }

    private func statTile(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.blipzDisplay(size: 24, weight: .bold))
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(value) \(label)")
    }

    // MARK: - Last 5 days
    //
    // "All history ›" is a static placeholder — there's no full-history screen yet.

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Last 5 days")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("All history ›")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.accent)
            }

            // GeometryReader computes a real per-tile width instead of relying on
            // .aspectRatio(1, contentMode: .fit), which — even inside a flexible grid —
            // was still resolving against an effectively-unbounded proposed height and
            // collapsing to a tiny square. This guarantees true ~56pt tiles that also
            // span the full content width, per the addendum's explicit spec.
            GeometryReader { geo in
                let spacing: CGFloat = 8
                let tileSize = (geo.size.width - spacing * 4) / 5
                HStack(spacing: spacing) {
                    ForEach(last5Days, id: \.date) { day in
                        historyTile(day, size: tileSize)
                    }
                }
            }
            .frame(height: 82)

            // The scoring formula changed on 2026-08-06 (see backend app/scoring.py) —
            // a tile from before that date is on the old unweighted /35 scale, not
            // directly comparable to a /100 tile right next to it. Only shown while the
            // visible 5-day window actually straddles the cutover; disappears on its own
            // once every visible day is past it.
            if last5Days.contains(where: { $0.isLegacyScoring && $0.score != nil }) {
                Text("† from before the scoring update — not directly comparable")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 20)
        .padding(.bottom, 20)
    }

    private var last5Days: [(date: Date, label: String, score: Double?, isLegacyScoring: Bool)] {
        let calendar = Calendar.current
        return (0..<5).reversed().map { offset in
            let day = calendar.date(byAdding: .day, value: -offset, to: .now) ?? .now
            let key = isoDateString(day)
            let entry = history.first(where: { $0.date == key })
            return (day, day.formatted(.dateTime.weekday(.abbreviated)), entry?.totalScore, entry?.scoringModel == "legacy_raw_35")
        }
    }

    private func isoDateString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = .current
        return formatter.string(from: date)
    }

    private func historyTile(_ day: (date: Date, label: String, score: Double?, isLegacyScoring: Bool), size: CGFloat) -> some View {
        let isToday = Calendar.current.isDateInToday(day.date)
        return VStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(isToday ? Theme.accent : Theme.surface)
                .frame(width: size, height: size)
                .overlay(
                    // Dropped to a whole number here specifically — five tiles at this
                    // size stay legible without a decimal; the precise score is still
                    // shown everywhere else (stat number, recap, leaderboard).
                    HStack(alignment: .firstTextBaseline, spacing: 1) {
                        Text(day.score.map { $0.formatted(.number.precision(.fractionLength(0))) } ?? "—")
                            .font(.blipzDisplay(size: 17, weight: .medium))
                        if day.isLegacyScoring, day.score != nil {
                            Text("†")
                                .font(.system(size: 11, weight: .medium))
                        }
                    }
                    .foregroundStyle(isToday ? .white : (day.score == nil ? .secondary : .primary))
                )
            Text(day.label)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(day.label), "
                + (day.score.map {
                    $0.formatted(.number.precision(.fractionLength(1)))
                        + (day.isLegacyScoring ? " out of 35, old scoring, not directly comparable" : " out of 100")
                } ?? "no score")
        )
    }

    // MARK: - Reminder
    //
    // Static placeholder — there's no local-notification system in the app yet.

    private var reminderRow: some View {
        VStack(spacing: 0) {
            Divider()
            HStack {
                Text("Daily reminder")
                Spacer()
                Text("off ›")
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 14)
            Divider()
        }
        .padding(.horizontal, 18)
    }

    // MARK: - Replay onboarding
    //
    // Same content shown on first launch, just presented on demand — doesn't touch
    // hasCompletedOnboarding, so it has no effect on future launches.

    private var howBlipzWorksRow: some View {
        VStack(spacing: 0) {
            Divider()
            Button {
                Haptics.light()
                showingOnboarding = true
            } label: {
                HStack {
                    Text("How Blipz works")
                        .foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color(.tertiaryLabel))
                }
                .padding(.vertical, 14)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint("Replays the intro screen")
            Divider()
        }
        .padding(.horizontal, 18)
    }
}

#Preview {
    YouView()
}
