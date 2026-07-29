import SwiftUI

struct LeaderboardView: View {
    @State private var viewModel = LeaderboardViewModel()
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
                }

                if viewModel.isLoading {
                    ProgressView()
                } else if let error = viewModel.errorMessage {
                    Text(error)
                        .foregroundStyle(.secondary)
                } else {
                    List(entries) { entry in
                        HStack {
                            Text("#\(entry.rank)")
                                .foregroundStyle(.secondary)
                                .frame(width: 40, alignment: .leading)
                            Text(entry.username)
                            Spacer()
                            Text(entry.totalScore, format: .number.precision(.fractionLength(1)))
                                .bold()
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Leaderboard")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink("Friends") {
                        FriendsView()
                    }
                }
            }
            .task { await load() }
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

#Preview {
    LeaderboardView()
}
