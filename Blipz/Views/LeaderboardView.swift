import SwiftUI

struct LeaderboardView: View {
    @State private var viewModel = LeaderboardViewModel()
    @State private var profileViewModel = ProfileViewModel()
    @State private var scope = Scope.global
    @Environment(\.displayScale) private var displayScale

    enum Scope: String, CaseIterable {
        case global = "Global"
        case friends = "Friends"
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Picker("Scope", selection: $scope) {
                    ForEach(Scope.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                if let message = viewModel.dailyMessage, scope == .global {
                    dailyCommentaryCard(message)
                }

                if viewModel.isLoading {
                    ProgressView()
                        .accessibilityLabel("Loading leaderboard")
                } else if let error = viewModel.errorMessage {
                    Text(error)
                        .foregroundStyle(Theme.error)
                } else if entries.isEmpty {
                    emptyState
                } else {
                    if podiumEntries.count == 3 {
                        PodiumView(entries: podiumEntries)
                            .padding(.horizontal)
                    }

                    List(remainingEntries) { entry in
                        LeaderboardRow(entry: entry, isCurrentUser: isCurrentUser(entry))
                            .listRowBackground(
                                isCurrentUser(entry) ? Theme.accent.opacity(0.1) : Theme.cardBackground
                            )
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .screenBackground()
            .navigationTitle("Leaderboard")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if let streak = profileViewModel.profile?.currentStreak, streak > 0 {
                        Label("\(streak)", systemImage: "flame.fill")
                            .foregroundStyle(.orange)
                            .accessibilityLabel("\(streak) day streak")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if let profile = profileViewModel.profile {
                        let card = ScoreCardRenderer.image(for: profile, displayScale: displayScale)
                        ShareLink(item: card, preview: SharePreview("My Blipz Score", image: card)) {
                            Image(systemName: "square.and.arrow.up")
                        }
                        .accessibilityLabel("Share my score")
                    }
                }
            }
            .task {
                await load()
                await profileViewModel.loadProfile()
            }
            .onChange(of: scope) { _, _ in
                Haptics.light()
                Task { await load() }
            }
        }
    }

    private var entries: [LeaderboardEntry] {
        scope == .global ? viewModel.globalEntries : viewModel.friendsEntries
    }

    private var podiumEntries: [LeaderboardEntry] {
        Array(entries.prefix(3))
    }

    private var remainingEntries: [LeaderboardEntry] {
        podiumEntries.count == 3 ? Array(entries.dropFirst(3)) : entries
    }

    private func isCurrentUser(_ entry: LeaderboardEntry) -> Bool {
        guard let username = profileViewModel.profile?.username else { return false }
        return entry.username == username
    }

    private func dailyCommentaryCard(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Daily Commentary", systemImage: "bubble.left.and.bubble.right.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.accent)
            Text(message)
                .font(.subheadline)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
        .padding(.horizontal)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: scope == .friends ? "person.2.slash" : "trophy")
                .font(.system(size: 32))
                .foregroundStyle(.secondary)
            Text(scope == .friends ? "No friends on the board yet" : "No scores yet today")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            if scope == .friends {
                Text("Add friends to see how you stack up.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 40)
    }

    private func load() async {
        if scope == .global {
            await viewModel.loadGlobal()
        } else {
            await viewModel.loadFriends()
        }
    }
}

private struct LeaderboardRow: View {
    let entry: LeaderboardEntry
    var isCurrentUser: Bool = false

    var body: some View {
        HStack {
            Text("#\(entry.rank)")
                .font(.headline)
                .foregroundStyle(.secondary)
                .frame(width: 32, alignment: .leading)

            InitialsAvatar(name: entry.username, size: 32)

            Text(entry.username)
                .lineLimit(1)
                .truncationMode(.tail)
                .fontWeight(isCurrentUser ? .bold : .regular)

            if isCurrentUser {
                Text("You")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Theme.accent)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Theme.accent.opacity(0.15), in: Capsule())
            }

            Spacer(minLength: 8)

            Text(entry.totalScore, format: .number.precision(.fractionLength(1)))
                .bold()
                .foregroundStyle(Theme.accent)
        }
        .padding(.vertical, 6)
    }
}

private struct PodiumView: View {
    /// Exactly 3 entries, ranks 1-3 in order.
    let entries: [LeaderboardEntry]

    var body: some View {
        HStack(alignment: .bottom, spacing: 12) {
            column(for: entries[1], height: 90)
            column(for: entries[0], height: 112)
            column(for: entries[2], height: 72)
        }
        .frame(maxWidth: .infinity)
    }

    private func column(for entry: LeaderboardEntry, height: CGFloat) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "\(entry.rank).circle.fill")
                .font(.title2)
                .foregroundStyle(medalColor(entry.rank))

            InitialsAvatar(name: entry.username, size: entry.rank == 1 ? 52 : 44)

            Text(entry.username)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .frame(maxWidth: 84)

            Text(entry.totalScore, format: .number.precision(.fractionLength(1)))
                .font(.caption2)
                .foregroundStyle(.secondary)

            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(medalColor(entry.rank).opacity(0.25))
                .frame(height: height)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Rank \(entry.rank), \(entry.username), \(entry.totalScore.formatted(.number.precision(.fractionLength(1)))) points")
    }

    private func medalColor(_ rank: Int) -> Color {
        switch rank {
        case 1: return Theme.gold
        case 2: return Theme.silver
        case 3: return Theme.bronze
        default: return Theme.accent
        }
    }
}

private struct InitialsAvatar: View {
    let name: String
    var size: CGFloat = 36

    var body: some View {
        Circle()
            .fill(Theme.accent.opacity(0.15))
            .overlay(
                Text(initial)
                    .font(.system(size: size * 0.42, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.accent)
            )
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }

    private var initial: String {
        guard let first = name.trimmingCharacters(in: .whitespaces).first else { return "?" }
        return String(first).uppercased()
    }
}

#Preview {
    LeaderboardView()
}
