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
            .refreshable {
                await viewModel.loadProfile()
                await loadHistory()
            }
            .onAppear {
                Task {
                    await viewModel.loadProfile()
                    await loadHistory()
                }
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

    private var titleRow: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 6) {
                    Text("You")
                        .font(.largeTitle.weight(.bold))
                        .foregroundStyle(Theme.brandInk)
                    Text("DAILY BLIP").font(.caption2).foregroundStyle(.secondary)
                }
            } else {
                HStack {
                    Text("You")
                        .font(.largeTitle.weight(.bold))
                        .foregroundStyle(Theme.brandInk)
                    Spacer()
                    Text("DAILY BLIP").font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 10)
        .padding(.bottom, 24)
        .accessibilityAddTraits(.isHeader)
    }

    // MARK: - Identity

    private func identityRow(_ profile: UserProfile) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("A little more you.").font(.headline).foregroundStyle(Theme.brandInk)
            HStack(spacing: 14) {
                BlipzAvatar(name: displayName(profile), size: 64)
                VStack(alignment: .leading, spacing: 5) {
                    Text(displayName(profile)).font(.headline)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("Your daily corner of Blipz.")
                        .font(.caption).foregroundStyle(Theme.accent)
                }
                Spacer(minLength: 0)
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 2)
        .padding(.bottom, 22)
    }

    private func displayName(_ profile: UserProfile) -> String {
        profile.username ?? "guest_\(profile.id.prefix(8))"
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
                    statTile(value: "\(profile.currentStreak)", label: "Day streak", symbol: "flame", tint: Theme.streak)
                    Divider().frame(height: 44)
                    statTile(value: "\(profile.longestStreak)", label: "Best streak", symbol: "sparkles", tint: Theme.accent)
                    Divider().frame(height: 44)
                    statTile(value: profile.totalScore.formatted(.number.precision(.fractionLength(0...1))), label: "Today’s score", symbol: "bolt", tint: Theme.mathsAccent)
                }
            }
        }
        .premiumSurface(.elevated, cornerRadius: 16)
        .padding(.horizontal, 18)
    }

    private func statTile(value: String, label: String, symbol: String, tint: Color) -> some View {
        VStack(spacing: 7) {
            Image(systemName: symbol).font(.title3).foregroundStyle(tint).accessibilityHidden(true)
            Text(value)
                .font(.blipzDisplay(size: 25, weight: .bold)).foregroundStyle(Theme.brandInk)
            Text(label)
                .font(.caption2)
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
                .font(.blipzDisplay(size: 21, weight: .bold))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(value) \(label)")
    }

    // MARK: - Last 5 days

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Text("Last 5 days").font(.subheadline.weight(.semibold)).foregroundStyle(Theme.brandInk)
                Spacer()
                Text("YOUR RECENT BLIPS").font(.caption2).foregroundStyle(.secondary)
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
                    let tileSize = min(58, (geo.size.width - 28) / 5)
                    HStack(spacing: 0) {
                        ForEach(last5Days, id: \.date) { day in
                            historyTile(day, size: tileSize)
                            if day.date != last5Days.last?.date {
                                Spacer(minLength: 7)
                            }
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
            Text("A little curiosity, one day at a time.")
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding(.horizontal, 18)
        .padding(.top, 24)
        .padding(.bottom, 24)
    }

    private var last5Days: [(date: Date, label: String, score: Double?, isLegacyScoring: Bool)] {
        let calendar = BlipzDay.calendar
        return (0..<5).reversed().map { offset in
            let day = calendar.date(byAdding: .day, value: -offset, to: .now) ?? .now
            let key = isoDateString(day)
            let entry = history.first(where: { $0.date == key })
            return (day, day.formatted(.dateTime.weekday(.abbreviated)), entry?.totalScore, entry?.scoringModel == "legacy_raw_35")
        }
    }

    private func isoDateString(_ date: Date) -> String {
        BlipzDay.key(for: date)
    }

    private func historyTile(_ day: (date: Date, label: String, score: Double?, isLegacyScoring: Bool), size: CGFloat) -> some View {
        let isToday = BlipzDay.calendar.isDateInToday(day.date)
        return VStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(isToday ? Theme.buttonFill : Theme.secondarySurface)
                .frame(width: size, height: size)
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(isToday ? Color.clear : Theme.hairline, lineWidth: 0.5)
                )
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
            Text(isToday ? "Today" : day.label)
                .font(.caption2)
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
                .foregroundStyle(BlipzDay.calendar.isDateInToday(day.date) ? Theme.accent : .primary)
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
    // No notification system exists yet: render an honest passive status, not a toggle.

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
            .padding(.horizontal, 12)
            .padding(.vertical, 11)

            Divider().padding(.leading, 52)

            Button {
                Haptics.light()
                showingOnboarding = true
            } label: {
                HStack(spacing: 10) {
                    BlipzSymbolTile(symbol: "questionmark", tint: Theme.accentPressed, size: 28)
                    Text("How Blipz works")
                        .foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color(.tertiaryLabel))
                }
                .font(.subheadline)
                .padding(.horizontal, 12)
                .padding(.vertical, 11)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint("Replays the intro screen")

            Divider().padding(.leading, 52)

            ShareLink(item: profileInviteText) {
                HStack(spacing: 10) {
                    BlipzSymbolTile(symbol: "person.badge.plus", tint: Theme.accent, size: 28)
                    Text("Invite a friend").foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: "square.and.arrow.up").foregroundStyle(Theme.accent)
                }
                .font(.subheadline).padding(.horizontal, 12).padding(.vertical, 13)
                .frame(minHeight: 48)
            }.buttonStyle(.plain)
        }
        .premiumSurface(.elevated, cornerRadius: 16)
        .padding(.horizontal, 18)
        .padding(.bottom, 18)
    }

    private var reminderLabel: some View {
        HStack(spacing: 10) {
            BlipzSymbolTile(symbol: "bell.fill", tint: Theme.accentPressed, size: 28)
            Text("Daily reminder")
        }
        .font(.subheadline)
    }

    private var reminderStatus: some View {
        HStack(spacing: 8) {
            Text("Not available yet")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var profileInviteText: String {
        viewModel.profile?.username.map { "Play Blipz with me — add me as a friend: \($0)" }
            ?? "Play Blipz with me — three quick daily games, one combined score."
    }
}

#Preview {
    YouView()
}
