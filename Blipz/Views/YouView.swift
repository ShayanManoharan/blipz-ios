import SwiftUI

struct YouView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
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
                        menuSection
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
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 6) {
                    Text("You")
                        .font(.system(size: 30, weight: .bold))
                    Text("Settings ›")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            } else {
                HStack {
                    Text("You")
                        .font(.system(size: 30, weight: .bold))
                    Spacer()
                    Text("Settings ›")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 14)
        .padding(.bottom, 16)
    }

    // MARK: - Identity
    //
    // "Pick a username ›" is a static placeholder — there's no username-setting
    // endpoint yet, so it can't actually do anything if tapped.

    private func identityRow(_ profile: UserProfile) -> some View {
        HStack(spacing: 14) {
            Circle()
                .fill(Theme.accent.opacity(0.15))
                .frame(width: 56, height: 56)
                .overlay(
                    Text(initial(displayName(profile)))
                        .font(.title2.weight(.bold))
                        .foregroundStyle(Theme.accent)
                )
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(displayName(profile))
                    .font(.title3.weight(.semibold))
                Text("Pick a username ›")
                    .font(.caption)
                    .foregroundStyle(Theme.accent)
            }
            Spacer()
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 20)
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
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(spacing: 0) {
                    statListRow(value: "\(profile.currentStreak)", label: "Day streak")
                    Divider()
                    statListRow(value: "\(profile.longestStreak)", label: "Best streak")
                    Divider()
                    statListRow(
                        value: profile.totalScore.formatted(.number.precision(.fractionLength(1))),
                        label: "Today"
                    )
                }
            } else {
                HStack(spacing: 0) {
                    statTile(value: "\(profile.currentStreak)", label: "day streak")
                    Divider().frame(height: 44)
                    statTile(value: "\(profile.longestStreak)", label: "best streak")
                    Divider().frame(height: 44)
                    statTile(value: profile.totalScore.formatted(.number.precision(.fractionLength(1))), label: "today")
                }
            }
        }
        .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Theme.hairline.opacity(0.7), lineWidth: 0.5)
        )
        .padding(.horizontal, 18)
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
        .padding(.vertical, 16)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(value) \(label)")
    }

    private func statListRow(value: String, label: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer(minLength: 12)
            Text(value)
                .font(.blipzDisplay(size: 24, weight: .bold))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
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

            if dynamicTypeSize.isAccessibilitySize {
                VStack(spacing: 0) {
                    ForEach(Array(last5Days.enumerated()), id: \.element.date) { index, day in
                        historyListRow(day)
                        if index < last5Days.count - 1 {
                            Divider()
                        }
                    }
                }
            } else {
                // GeometryReader guarantees equally sized tiles across the card.
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
            }

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
        .padding(16)
        .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Theme.hairline.opacity(0.7), lineWidth: 0.5)
        )
        .padding(.horizontal, 18)
        .padding(.top, 18)
        .padding(.bottom, 18)
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

    private func historyListRow(_ day: (date: Date, label: String, score: Double?, isLegacyScoring: Bool)) -> some View {
        let score = day.score.map {
            $0.formatted(.number.precision(.fractionLength(1)))
                + (day.isLegacyScoring ? "†" : "")
        } ?? "—"

        return HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(day.label)
                .foregroundStyle(.secondary)
            Spacer(minLength: 12)
            Text(score)
                .font(.blipzDisplay(size: 20, weight: .semibold))
                .foregroundStyle(Calendar.current.isDateInToday(day.date) ? Theme.accent : .primary)
        }
        .padding(.vertical, 10)
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

    // MARK: - Menu

    private var menuSection: some View {
        VStack(spacing: 0) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) {
                    reminderLabel
                    Spacer()
                    reminderStatus
                }

                VStack(alignment: .leading, spacing: 8) {
                    reminderLabel
                    reminderStatus
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)

            Divider().padding(.leading, 48)

            Button {
                Haptics.light()
                showingOnboarding = true
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "questionmark.circle")
                        .frame(width: 22)
                        .foregroundStyle(.secondary)
                    Text("How Blipz works")
                        .foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color(.tertiaryLabel))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 14)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint("Replays the intro screen")
        }
        .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Theme.hairline.opacity(0.7), lineWidth: 0.5)
        )
        .padding(.horizontal, 18)
        .padding(.bottom, 24)
    }

    private var reminderLabel: some View {
        HStack(spacing: 12) {
            Image(systemName: "bell")
                .frame(width: 22)
                .foregroundStyle(.secondary)
            Text("Daily reminder")
        }
    }

    private var reminderStatus: some View {
        HStack(spacing: 8) {
            Text("Off")
                .foregroundStyle(.secondary)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color(.tertiaryLabel))
        }
    }
}

#Preview {
    YouView()
}
