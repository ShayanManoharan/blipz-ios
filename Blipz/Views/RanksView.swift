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
    }

    private var addFriendButton: some View {
        Button {
            Haptics.light()
            scope = .friends
        } label: {
            Label("Add friend", systemImage: "plus")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.accent)
        }
        .accessibilityHint("Switches to the Friends tab")
    }

    // Underlined text tabs, not a filled iOS segmented control.
    private var segmentTabs: some View {
        HStack(spacing: 18) {
            ForEach(Scope.allCases, id: \.self) { s in
                Button {
                    scope = s
                } label: {
                    VStack(spacing: 6) {
                        Text(s.rawValue)
                            .font(.subheadline.weight(scope == s ? .semibold : .regular))
                            .foregroundStyle(scope == s ? .primary : .secondary)
                        Rectangle()
                            .fill(scope == s ? Theme.accent : .clear)
                            .frame(height: 1.5)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(scope == s ? .isSelected : [])
            }
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 6)
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
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(Color.primary.opacity(0.85), lineWidth: 1.5)
                    )

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
            .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Theme.hairline.opacity(0.24), lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.04), radius: 7, y: 3)
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
        .background(mine ? Theme.accentWash : Color.clear)
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
            InitialsAvatar(name: entry.username, size: 28)
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
                InitialsAvatar(name: entry.username, size: 28)
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
            .background(Theme.surface.opacity(0.55), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .padding(.horizontal, 18)
            .padding(.top, 12)
        } else {
            Text("No scores yet today")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .padding(.top, 40)
        }
    }

    private var globalTail: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                Circle()
                    .fill(Theme.surface.opacity(0.85))
                    .frame(width: 34, height: 34)
                    .overlay(
                        Image(systemName: "globe")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Theme.accent)
                    )
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 1) {
                    Text("That's everyone so far.")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                    Text("The board fills up through the day.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }

            compactInviteLink(label: "Invite a friend")
        }
        .padding(12)
        .background(Theme.surface.opacity(0.42), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Theme.hairline.opacity(0.18), lineWidth: 0.5)
        )
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
            .background(Theme.accent, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
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
                    .font(.system(size: size * 0.42, weight: .bold))
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
    RanksView()
}
