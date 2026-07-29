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
            .frame(maxWidth: .infinity, maxHeight: .infinity)
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
    var isSelected: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.medium))
            .multilineTextAlignment(.center)
            .foregroundStyle(isSelected ? .white : Theme.accent)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isSelected ? Theme.accent : Theme.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Theme.accent.opacity(isSelected ? 0 : 0.35), lineWidth: 1.5)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
    }
}

struct ResultCard: View {
    let title: String
    var subtitle: String? = nil

    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.accent)
            if let subtitle {
                Text(subtitle)
                    .foregroundStyle(.secondary)
            }
        }
        .cardStyle()
    }
}
