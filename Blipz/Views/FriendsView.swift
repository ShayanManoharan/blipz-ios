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
                        Task { await viewModel.addFriend() }
                    }
                    .disabled(viewModel.usernameToAdd.isEmpty)
                }
                .padding(.horizontal)

                if let success = viewModel.addSuccessMessage {
                    Text(success)
                        .foregroundStyle(.green)
                }
                if let error = viewModel.errorMessage {
                    Text(error)
                        .foregroundStyle(.secondary)
                }

                List(viewModel.friends) { friend in
                    Text(friend.username)
                }
                .listStyle(.plain)
            }
            .navigationTitle("Friends")
            .task { await viewModel.loadFriends() }
        }
    }
}

#Preview {
    FriendsView()
}
