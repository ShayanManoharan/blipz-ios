import SwiftUI

struct RanksView: View {
    @State private var viewModel = LeaderboardViewModel()
    @State private var profileViewModel = ProfileViewModel()
    @State private var addViewModel = FriendsViewModel()
    @State private var scope = Scope.global

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
                    Divider()

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
        HStack {
            Text("Ranks")
                .font(.system(size: 28, weight: .bold))
            Spacer()
            Button {
                Haptics.light()
                scope = .friends
            } label: {
                Text("＋ Add friend")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.accent)
            }
            .accessibilityHint("Switches to the Friends tab")
        }
        .padding(.horizontal, 18)
        .padding(.top, 14)
        .padding(.bottom, 12)
    }

    // Underlined text tabs, not a filled iOS segmented control.
    private var segmentTabs: some View {
        HStack(spacing: 24) {
            ForEach(Scope.allCases, id: \.self) { s in
                Button {
                    scope = s
                } label: {
                    VStack(spacing: 6) {
                        Text(s.rawValue)
                            .font(.subheadline.weight(scope == s ? .semibold : .regular))
                            .foregroundStyle(scope == s ? .primary : .secondary)
                        Rectangle()
                            .fill(scope == s ? Color.primary.opacity(0.85) : .clear)
                            .frame(height: 2)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(scope == s ? .isSelected : [])
            }
            Spacer()
        }
        .padding(.horizontal, 18)
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
            // Dividers stay full-bleed on purpose; each row carries its own 18pt inset
            // directly (same pattern as titleRow/segmentTabs) so the highlight background
            // lines up with the title exactly instead of drifting from an ancestor's
            // padding.
            VStack(spacing: 0) {
                Divider()
                ForEach(entries) { entry in
                    rankRow(entry)
                    Divider()
                }
            }

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

    // Marked by a pale green background, green rank number, and bold weight only —
    // no "You" badge pill.
    // A plain HStack containing a Spacer (or any other "greedy width" child —
    // .frame(maxWidth: .infinity) reproduced the exact same thing) silently ignores a
    // wrapping .padding(.horizontal:) in this specific ancestor chain: the padding
    // compiles and reports the right size, but the rendered row still bleeds edge to
    // edge. Confirmed by bisection — removing the greedy child fixes it, adding one
    // back (Spacer, or frame(maxWidth: .infinity) + .overlay(alignment: .trailing))
    // reintroduces it every time. GeometryReader sidesteps the bug entirely by
    // computing the inset width explicitly instead of relying on the automatic
    // proposal/negotiation that's misbehaving here.
    private func rankRow(_ entry: LeaderboardEntry) -> some View {
        let mine = isCurrentUser(entry)
        return GeometryReader { geo in
            HStack(spacing: 12) {
                Text("\(entry.rank)")
                    .font(.subheadline.weight(mine ? .bold : .regular))
                    .foregroundStyle(mine ? Theme.accent : .secondary)
                    .frame(width: 24, alignment: .leading)

                InitialsAvatar(name: entry.username, size: 32)

                Text(entry.username)
                    .font(.body.weight(mine ? .bold : .regular))
                    .lineLimit(1)
                    .truncationMode(.tail)

                Spacer(minLength: 8)

                Text(entry.totalScore, format: .number.precision(.fractionLength(1)))
                    .font(.blipzDisplay(size: 17, weight: .medium))
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .frame(width: geo.size.width - 36, alignment: .leading)
            .background(mine ? Theme.accentWash : Color.clear, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .offset(x: 18)
        }
        .frame(height: 56)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "Rank \(entry.rank), \(entry.username)\(mine ? ", you" : ""), "
                + "\(entry.totalScore.formatted(.number.precision(.fractionLength(1)))) points"
        )
    }

    @ViewBuilder
    private var emptyState: some View {
        if scope == .friends {
            VStack(spacing: 10) {
                Text("Nobody to beat yet")
                    .font(.title3.weight(.medium))
                Text("Add one friend and the daily score turns into an argument.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                inviteShareLink(label: "Share invite link")
                    .buttonStyle(OutlineButtonStyle())
                    .padding(.top, 8)
            }
            .frame(maxWidth: .infinity)
            .padding(20)
            .outlinedContainer()
            .padding(.horizontal, 18)
            .padding(.top, 20)
        } else {
            Text("No scores yet today")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .padding(.top, 40)
        }
    }

    private var globalTail: some View {
        VStack(spacing: 14) {
            VStack(spacing: 2) {
                Text("That's everyone so far.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text("The board fills up through the day.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .multilineTextAlignment(.center)

            inviteShareLink(label: "Invite a friend")
                .buttonStyle(PrimaryButtonStyle())
        }
        .padding(.top, 24)
        .padding(.bottom, 24)
        .padding(.horizontal, 18)
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
