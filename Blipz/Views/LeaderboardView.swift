import SwiftUI

struct LeaderboardView: View {
    @State private var viewModel = LeaderboardViewModel()
    @State private var profileViewModel = ProfileViewModel()
    @State private var scope = Scope.global

    enum Scope: String, CaseIterable {
        case global = "Global"
        case friends = "Friends"
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                Picker("Scope", selection: $scope) {
                    ForEach(Scope.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                if let message = viewModel.dailyMessage, scope == .global {
                    Text(message)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .cardStyle()
                        .padding(.horizontal)
                }

                if viewModel.isLoading {
                    ProgressView()
                } else if let error = viewModel.errorMessage {
                    Text(error)
                        .foregroundStyle(.secondary)
                } else {
                    List(entries) { entry in
                        LeaderboardRow(entry: entry)
                            .listRowBackground(Theme.cardBackground)
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
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink("Friends") {
                        FriendsView()
                    }
                }
            }
            .task {
                await load()
                await profileViewModel.loadProfile()
            }
            .onChange(of: scope) { _, _ in
                Task { await load() }
            }
        }
    }

    private var entries: [LeaderboardEntry] {
        scope == .global ? viewModel.globalEntries : viewModel.friendsEntries
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

    var body: some View {
        HStack {
            Group {
                if let medal {
                    Text(medal)
                } else {
                    Text("#\(entry.rank)")
                        .foregroundStyle(.secondary)
                }
            }
            .font(.headline)
            .frame(width: 40, alignment: .leading)

            Text(entry.username)
                .fontWeight(entry.rank <= 3 ? .semibold : .regular)
            Spacer()
            Text(entry.totalScore, format: .number.precision(.fractionLength(1)))
                .bold()
                .foregroundStyle(Theme.accent)
        }
        .padding(.vertical, 4)
    }

    private var medal: String? {
        switch entry.rank {
        case 1: return "🥇"
        case 2: return "🥈"
        case 3: return "🥉"
        default: return nil
        }
    }
}

#Preview {
    LeaderboardView()
}
