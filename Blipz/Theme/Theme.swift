import SwiftUI

enum Theme {
    static let accent = Color.accentColor

    static let background = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.07, green: 0.07, blue: 0.09, alpha: 1)
            : UIColor(red: 0.97, green: 0.96, blue: 1.00, alpha: 1)
    })

    static let cardBackground = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.15, green: 0.15, blue: 0.18, alpha: 1)
            : UIColor.white
    })

    static let success = Color(red: 0.20, green: 0.70, blue: 0.45)
    static let streak = Color.orange
}

private struct CardBackgroundModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(20)
            .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: .black.opacity(0.06), radius: 10, y: 4)
    }
}

private struct ScreenBackgroundModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(Theme.background.ignoresSafeArea())
    }
}

extension View {
    func cardStyle() -> some View { modifier(CardBackgroundModifier()) }
    func screenBackground() -> some View { modifier(ScreenBackgroundModifier()) }
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.accent))
            .opacity(configuration.isPressed ? 0.85 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

struct OptionButtonStyle: ButtonStyle {
    enum State {
        case normal
        case selected
        case correct
        case incorrect
        case dimmed
    }

    var state: State = .normal

    private var fillColor: Color {
        switch state {
        case .normal, .dimmed: return Theme.cardBackground
        case .selected: return Theme.accent
        case .correct: return Theme.success
        case .incorrect: return .red
        }
    }

    private var foregroundColor: Color {
        switch state {
        case .normal, .dimmed: return Theme.accent
        case .selected, .correct, .incorrect: return .white
        }
    }

    private var borderOpacity: Double {
        switch state {
        case .normal: return 0.35
        case .dimmed: return 0.15
        case .selected, .correct, .incorrect: return 0
        }
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.medium))
            .multilineTextAlignment(.center)
            .foregroundStyle(foregroundColor)
            .opacity(state == .dimmed ? 0.5 : 1)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(fillColor)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Theme.accent.opacity(borderOpacity), lineWidth: 1.5)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
    }
}

struct ResultCard: View {
    let title: String
    var subtitle: String? = nil
    @ScaledMetric(relativeTo: .largeTitle) private var titleFontSize: CGFloat = 34

    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.system(size: titleFontSize, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.accent)
            if let subtitle {
                Text(subtitle)
                    .foregroundStyle(.secondary)
            }
        }
        .cardStyle()
        .accessibilityElement(children: .combine)
    }
}
