import SwiftUI

struct RanksView: View {
    @State private var viewModel = LeaderboardViewModel()
    @State private var profileViewModel = ProfileViewModel()
    @State private var addViewModel = FriendsViewModel()
    @State private var scope = Scope.global
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    enum Scope: String, CaseIterable {
        case global = "Global"
        case friends = "Friends"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    titleRow
                    segmentTabs
                    if scope == .friends {
                        addFriendField
                    }

                    content
                }
            }
            .screenBackground()
            .toolbar(.hidden, for: .navigationBar)
            .task {
                await viewModel.loadGlobal()
                await profileViewModel.loadProfile()
            }
            .onChange(of: scope) { _, newScope in
                Haptics.light()
                if newScope == .friends, viewModel.friendsEntries.isEmpty {
                    Task { await viewModel.loadFriends() }
                }
            }
        }
    }

    // MARK: - Title + segments

    private var titleRow: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 10) {
                    ranksTitle
                    addFriendButton
                }
            } else {
                HStack {
                    ranksTitle
                    Spacer()
                    addFriendButton
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 10)
        .padding(.bottom, 8)
    }

    private var ranksTitle: some View {
        Text("Ranks")
            .font(.system(size: 28, weight: .bold))
            .foregroundStyle(Theme.accentPressed)
    }

    private var addFriendButton: some View {
        Button {
            Haptics.light()
            scope = .friends
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "plus")
                    .font(.system(size: 11, weight: .semibold))
                    .frame(width: 20, height: 20)
                    .background(Theme.accentSurface, in: Circle())
                Text("Add friend")
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(Theme.accentPressed)
        }
        .accessibilityHint("Switches to the Friends tab")
    }

    private var segmentTabs: some View {
        HStack(spacing: 0) {
            ForEach(Scope.allCases, id: \.self) { s in
                Button {
                    scope = s
                } label: {
                    Text(s.rawValue)
                        .font(.subheadline.weight(scope == s ? .semibold : .regular))
                        .foregroundStyle(scope == s ? Color.white : Color.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(
                        scope == s ? Theme.accentPressed : Color.clear,
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                    )
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(scope == s ? .isSelected : [])
            }
        }
        .padding(3)
        .background(Theme.cardBackground.opacity(0.70), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 15).strokeBorder(Theme.hairline, lineWidth: 0.5))
        .padding(.horizontal, 18)
        .padding(.bottom, 4)
    }

    // MARK: - Add-by-username (Friends segment only, always at the top)

    private var addFriendField: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                TextField("Add by username", text: $addViewModel.usernameToAdd)
                    .textFieldStyle(.plain)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding(12)
                    .background(Theme.secondarySurface, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Theme.hairline, lineWidth: 0.5))

                Button("Add") {
                    Haptics.light()
                    Task {
                        await addViewModel.addFriend()
                        if addViewModel.errorMessage == nil {
                            await viewModel.loadFriends()
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.accent)
                .disabled(addViewModel.usernameToAdd.isEmpty)
            }

            if let success = addViewModel.addSuccessMessage {
                Text(success)
                    .font(.caption)
                    .foregroundStyle(Theme.success)
            }
            if let error = addViewModel.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(Theme.error)
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 14)
        .padding(.bottom, 6)
    }

    // MARK: - List content

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading {
            ProgressView()
                .accessibilityLabel("Loading \(scope.rawValue.lowercased()) ranks")
                .frame(maxWidth: .infinity)
                .padding(.top, 60)
        } else if let error = viewModel.errorMessage {
            Text(error)
                .foregroundStyle(Theme.error)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
                .padding(.top, 40)
        } else if entries.isEmpty {
            emptyState
        } else {
            VStack(spacing: 0) {
                ForEach(entries) { entry in
                    rankRow(entry)
                    if entry.id != entries.last?.id {
                        Divider().padding(.leading, 58)
                    }
                }
            }
            .premiumSurface(.elevated, cornerRadius: 16)
            .padding(.horizontal, 18)
            .padding(.top, 8)

            if scope == .global {
                globalTail
            }
        }
    }

    // /leaderboard/friends always includes the caller's own row, even with zero
    // friends — showing just yourself isn't "populated", it's the empty state with an
    // extra row, so it's excluded entirely until there's at least one other entry.
    private var entries: [LeaderboardEntry] {
        guard scope == .friends else { return viewModel.globalEntries }
        let others = viewModel.friendsEntries.filter { !isCurrentUser($0) }
        return others.isEmpty ? [] : viewModel.friendsEntries
    }

    private func isCurrentUser(_ entry: LeaderboardEntry) -> Bool {
        guard let username = profileViewModel.profile?.username else { return false }
        return entry.username == username
    }

    private func rankRow(_ entry: LeaderboardEntry) -> some View {
        let mine = isCurrentUser(entry)
        return Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 10) {
                    accessibleRankIdentity(entry, mine: mine)
                    rankScore(entry)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            } else {
                HStack(spacing: 9) {
                    rankIdentity(entry, mine: mine)
                    Spacer(minLength: 6)
                    rankScore(entry)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(mine ? Theme.accentSurface : Color.clear)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "Rank \(entry.rank), \(entry.username)\(mine ? ", you" : ""), "
                + "\(entry.totalScore.formatted(.number.precision(.fractionLength(1)))) out of 100 points"
        )
    }

    private func rankIdentity(_ entry: LeaderboardEntry, mine: Bool) -> some View {
        HStack(spacing: 9) {
            Text("\(entry.rank)")
                .font(.subheadline.weight(mine ? .bold : .regular))
                .foregroundStyle(mine ? Theme.accent : .secondary)
                .frame(width: 20, alignment: .leading)
            BlipzAvatar(name: entry.username, size: 28)
            Text(entry.username)
                .font(.subheadline.weight(mine ? .semibold : .regular))
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
                .truncationMode(.tail)
        }
    }

    private func accessibleRankIdentity(_ entry: LeaderboardEntry, mine: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Text("\(entry.rank)")
                    .font(.subheadline.weight(mine ? .bold : .regular))
                    .foregroundStyle(mine ? Theme.accent : .secondary)
                BlipzAvatar(name: entry.username, size: 28)
            }
            Text(entry.username)
                .font(.body.weight(mine ? .semibold : .regular))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func rankScore(_ entry: LeaderboardEntry) -> some View {
        HStack(alignment: .lastTextBaseline, spacing: 3) {
            Text(entry.totalScore, format: .number.precision(.fractionLength(1)))
                .font(.blipzDisplay(size: 16, weight: .medium))
                .foregroundStyle(isCurrentUser(entry) ? Theme.accent : .primary)
            Text("/100")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        if scope == .friends {
            VStack(spacing: 8) {
                Text("Nobody to beat yet")
                    .font(.headline)
                Text("Add one friend and the daily score turns into an argument.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                compactInviteLink(label: "Share invite link")
                    .padding(.top, 2)
            }
            .frame(maxWidth: .infinity)
            .padding(14)
            .premiumSurface(.neutral, cornerRadius: 13, shadow: false)
            .padding(.horizontal, 18)
            .padding(.top, 12)
        } else {
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Theme.accentSurface)
                        .frame(width: 72, height: 72)
                    Image(systemName: "globe.americas.fill")
                        .font(.system(size: 32, weight: .medium))
                        .foregroundStyle(Theme.accentPressed)
                }

                VStack(spacing: 2) {
                    Text("No scores yet today")
                        .font(.subheadline.weight(.semibold))
                    Text("Be the first on today's board.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .multilineTextAlignment(.center)

                compactInviteLink(label: "Invite a friend")
            }
            .frame(maxWidth: .infinity)
            .padding(14)
            .premiumSurface(.neutral, cornerRadius: 16, shadow: false)
            .padding(.horizontal, 18)
            .padding(.top, 12)
        }
    }

    private var globalTail: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Theme.accentSurface)
                    .frame(width: 72, height: 72)
                Image(systemName: "globe.americas.fill")
                    .font(.system(size: 32, weight: .medium))
                    .foregroundStyle(Theme.accentPressed)
            }

            VStack(spacing: 2) {
                Text("That's everyone so far.")
                    .font(.subheadline.weight(.semibold))
                Text("The board fills up through the day.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .multilineTextAlignment(.center)

            compactInviteLink(label: "Invite a friend")
        }
        .frame(maxWidth: .infinity)
        .padding(14)
        .premiumSurface(.neutral, cornerRadius: 16, shadow: false)
        .padding(.horizontal, 18)
        .padding(.top, 12)
    }

    // Real, working share sheet (no fabricated invite link/code — the app has no such
    // system) — shares the player's own username so a friend can add them for real via
    // the Friends segment's add-by-username field.
    private func inviteShareLink(label: String) -> some View {
        let text = profileViewModel.profile?.username.map {
            "Play Blipz with me — add me as a friend: \($0)"
        } ?? "Play Blipz with me — three quick daily games, one combined score."

        return ShareLink(item: text) {
            Text(label)
        }
    }

    private func compactInviteLink(label: String) -> some View {
        inviteShareLink(label: label)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 9)
            .background(Theme.accentPressed, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

#Preview {
    RanksView()
}
