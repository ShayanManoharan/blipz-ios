import SwiftUI

struct MathGameView: View {
    @State private var viewModel = MathGameViewModel()
    @State private var profileViewModel = ProfileViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            GameModalBar(title: "QUICK MATHS") {
                timer
            }
            .padding(.horizontal, 14)
            .padding(.top, 4)

            switch viewModel.phase {
            case .notStarted:
                loadingState
            case .playing:
                playingContent
            case .finished:
                finishedContent
            }

            if let error = viewModel.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(Theme.error)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
        }
        .screenBackground()
        .toolbar(.hidden, for: .navigationBar)
        .task {
            await viewModel.loadDailyContent()
            await profileViewModel.loadProfile()
            if viewModel.phase == .notStarted, !viewModel.problems.isEmpty {
                viewModel.start()
            }
        }
    }

    // One timer for the whole round (startDate is set once by viewModel.start() and
    // never reset per-question) — counts down from roundSeconds rather than up, matching
    // the "20 problems, 90 seconds" framing already used on Today's up-next card.
    private static let roundSeconds: TimeInterval = 90

    @ViewBuilder
    private var timer: some View {
        if let startDate = viewModel.startDate, viewModel.phase == .playing {
            TimelineView(.periodic(from: startDate, by: 0.1)) { context in
                let elapsed = context.date.timeIntervalSince(startDate)
                let remaining = max(0, Self.roundSeconds - elapsed)
                Text(countdownString(remaining))
                    .font(.blipzDisplay(size: 17, weight: .medium))
                    .foregroundStyle(Theme.accent)
                    .lineLimit(1)
                    .fixedSize()
                    .accessibilityLabel("\(Int(remaining)) seconds remaining")
            }
        } else {
            Color.clear
        }
    }

    private func countdownString(_ seconds: TimeInterval) -> String {
        let total = Int(seconds.rounded())
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    // Display-only formatting — MathProblem.question/answer (the scoring path) are
    // untouched, this just swaps the ASCII operators for their typographic equivalents
    // on the way to the screen.
    private func displayQuestion(_ problem: MathProblem) -> String {
        problem.question
            .replacingOccurrences(of: "*", with: "×")
            .replacingOccurrences(of: "/", with: "÷")
            .replacingOccurrences(of: "-", with: "−")
    }

    private var loadingState: some View {
        VStack {
            Spacer()
            ProgressView()
                .accessibilityLabel("Loading today's problems")
            Spacer()
        }
    }

    // MARK: - Playing

    private var playingContent: some View {
        VStack(spacing: 0) {
            progressHeader

            Spacer(minLength: 12)

            if let problem = viewModel.currentProblem {
                VStack(spacing: 14) {
                    Text(displayQuestion(problem))
                        .font(.blipzDisplay(size: 52, weight: .medium))
                        .id(viewModel.currentDisplayIndex)
                        .transition(.opacity)

                    Rectangle()
                        .fill(Color.primary.opacity(0.85))
                        .frame(width: 150, height: 2)

                    Text(viewModel.currentAnswerText.isEmpty ? " " : viewModel.currentAnswerText)
                        .font(.system(size: 30, weight: .regular))
                        .foregroundStyle(.secondary)
                        .frame(minHeight: 36)
                        .accessibilityLabel(
                            viewModel.currentAnswerText.isEmpty
                                ? "No answer typed yet"
                                : "Typed answer: \(viewModel.currentAnswerText)"
                        )
                }
            }

            Spacer(minLength: 12)

            keypad
        }
        // Without this, the VStack only ever reports its own minimum height upward and
        // the Spacers above/below the problem collapse to `minLength` instead of sharing
        // the screen's actual remaining space — the "dead zone" bug.
        .frame(maxHeight: .infinity)
        .animation(.easeOut(duration: 0.2), value: viewModel.currentDisplayIndex)
    }

    private var progressHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle().fill(Theme.hairline)
                    Rectangle().fill(Theme.accent).frame(width: geo.size.width * progressFraction)
                }
            }
            .frame(height: 3)
            .animation(.easeOut(duration: 0.2), value: viewModel.currentDisplayIndex)

            Text("\(viewModel.currentDisplayIndex) of \(viewModel.totalCount)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 18)
        .padding(.top, 8)
    }

    // A thin sliver once the round has started, even at 0 of 20 — a fully empty-looking
    // bar reads as broken, not "not started yet".
    private var progressFraction: CGFloat {
        guard viewModel.totalCount > 0 else { return 0 }
        return max(0.04, CGFloat(viewModel.currentDisplayIndex) / CGFloat(viewModel.totalCount))
    }

    // MARK: - Keypad

    private enum KeypadKey: Hashable {
        case digit(Int)
        case delete
        case enter
    }

    private static let keypadRows: [[KeypadKey]] = [
        [.digit(1), .digit(2), .digit(3)],
        [.digit(4), .digit(5), .digit(6)],
        [.digit(7), .digit(8), .digit(9)],
        [.delete, .digit(0), .enter],
    ]

    private var keypad: some View {
        VStack(spacing: 8) {
            ForEach(Self.keypadRows, id: \.self) { row in
                HStack(spacing: 8) {
                    ForEach(row, id: \.self) { key in
                        keypadButton(key)
                    }
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 16)
    }

    @ViewBuilder
    private func keypadButton(_ key: KeypadKey) -> some View {
        switch key {
        case .digit(let d):
            Button {
                Haptics.light()
                viewModel.currentAnswerText.append("\(d)")
                viewModel.checkAnswer()
            } label: {
                Text("\(d)")
                    .font(.title2.weight(.medium))
                    .frame(maxWidth: .infinity, minHeight: 52)
            }
            .buttonStyle(.plain)
            .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .accessibilityLabel("\(d)")

        case .delete:
            Button {
                Haptics.light()
                if !viewModel.currentAnswerText.isEmpty {
                    viewModel.currentAnswerText.removeLast()
                }
            } label: {
                Image(systemName: "delete.left")
                    .font(.body.weight(.medium))
                    .frame(maxWidth: .infinity, minHeight: 52)
            }
            .buttonStyle(.plain)
            .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .accessibilityLabel("Delete")

        case .enter:
            Button {
                let before = viewModel.currentDisplayIndex
                viewModel.checkAnswer()
                if viewModel.currentDisplayIndex == before {
                    Haptics.error()
                } else {
                    Haptics.light()
                }
            } label: {
                Text("Enter")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 52)
            }
            .buttonStyle(.plain)
            .background(Theme.accent, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .accessibilityLabel("Enter")
        }
    }

    // MARK: - Finished
    //
    // No dedicated wireframe frame for this state (Maths has no spoiler to reveal, so
    // there's nothing to chain past unlike Guess's §4) — reuses the same score-block +
    // chain-to-next-game pattern for consistency with Guess's result screen.

    // Maths is a stopwatch game: reaching 20/20 is the completion condition (you can't
    // advance past a problem without answering it correctly — see
    // MathGameViewModel.checkAnswer), not a meaningful score. Elapsed time is the only
    // thing that actually varies between runs, so it's the primary result; the
    // completion count is secondary context, not the headline.
    private var finishedContent: some View {
        VStack(spacing: 20) {
            Spacer(minLength: 24)

            VStack(spacing: 4) {
                if let elapsed = viewModel.elapsedTime {
                    Text(elapsedClockString(elapsed))
                        .font(.system(size: 52, weight: .bold))
                }
                Text("\(viewModel.result?.correct ?? viewModel.totalCount) problems completed")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 22)
            .outlinedContainer(emphasized: true)
            .padding(.horizontal, 18)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(
                viewModel.elapsedTime.map { "Maths complete, solved in \(elapsedString($0)), "
                    + "\(viewModel.result?.correct ?? viewModel.totalCount) problems completed" }
                    ?? "Maths, \(viewModel.result?.correct ?? viewModel.totalCount) out of \(viewModel.totalCount), complete"
            )

            nextButton
                .padding(.horizontal, 18)

            Spacer(minLength: 24)
        }
        .transition(.opacity)
    }

    @ViewBuilder
    private var nextButton: some View {
        if let profile = profileViewModel.profile, let next = BlipzGame.maths.nextUnplayed(in: profile) {
            NavigationLink {
                nextDestination(next)
            } label: {
                Text("Next: \(nextGameLabel(next))")
            }
            .buttonStyle(PrimaryButtonStyle())
            .simultaneousGesture(TapGesture().onEnded { Haptics.light() })
        } else {
            Button {
                Haptics.light()
                dismiss()
            } label: {
                Text("See today's score")
            }
            .buttonStyle(PrimaryButtonStyle())
        }
    }

    @ViewBuilder
    private func nextDestination(_ game: BlipzGame) -> some View {
        switch game {
        case .trivia: TriviaGameView().toolbar(.hidden, for: .tabBar)
        case .guess: GuessGameView().toolbar(.hidden, for: .tabBar)
        case .maths: EmptyView()
        }
    }

    private func nextGameLabel(_ game: BlipzGame) -> String {
        switch game {
        case .trivia: return "trivia"
        case .guess: return "guess the prompt"
        case .maths: return ""
        }
    }

    private func elapsedString(_ interval: TimeInterval) -> String {
        String(format: "%.1fs", interval)
    }

    // m:ss for the big result number — more scannable at a glance than "62.3s", and
    // matches the countdown's clock format above.
    private func elapsedClockString(_ interval: TimeInterval) -> String {
        let total = Int(interval.rounded())
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}

#Preview {
    MathGameView()
}
