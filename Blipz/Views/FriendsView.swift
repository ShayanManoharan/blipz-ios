import SwiftUI

struct FriendsView: View {
    @State private var viewModel = FriendsViewModel()

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                HStack {
                    TextField("Add friend by username", text: $viewModel.usernameToAdd)
                        .textFieldStyle(.roundedBorder)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
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
                        .foregroundStyle(Theme.error)
                }

                if viewModel.isLoading && viewModel.friends.isEmpty {
                    Spacer()
                    ProgressView("Loading friends…")
                    Spacer()
                } else if viewModel.friends.isEmpty {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "person.2")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                        Text("No friends yet")
                            .font(.headline)
                        Text("Add a friend by username to compare your daily scores.")
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    Spacer()
                } else {
                    List(viewModel.friends) { friend in
                        Text(friend.username)
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .listRowBackground(Theme.cardBackground)
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
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
