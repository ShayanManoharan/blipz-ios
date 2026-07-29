import SwiftUI

struct FriendsView: View {
    @State private var viewModel = FriendsViewModel()

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                HStack {
                    TextField("Add friend by username", text: $viewModel.usernameToAdd)
                        .textFieldStyle(.roundedBorder)
                        .autocapitalization(.none)
                    Button("Add") {
                        Haptics.light()
                        Task { await viewModel.addFriend() }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.accent)
                    .disabled(viewModel.usernameToAdd.isEmpty)
                }
                .padding(.horizontal)

                if let success = viewModel.addSuccessMessage {
                    Text(success)
                        .foregroundStyle(Theme.success)
                }
                if let error = viewModel.errorMessage {
                    Text(error)
                        .foregroundStyle(.secondary)
                }

                List(viewModel.friends) { friend in
                    Text(friend.username)
                        .listRowBackground(Theme.cardBackground)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
            .screenBackground()
            .navigationTitle("Friends")
            .task { await viewModel.loadFriends() }
        }
    }
}

#Preview {
    FriendsView()
}
