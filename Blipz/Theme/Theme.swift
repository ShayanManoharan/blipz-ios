import SwiftUI

enum Theme {
    static let accent = Color.accentColor

    // Direction 2a specifies a plain white background (no tint) — dark mode value
    // is unchanged since the wireframe is light-mode-only.
    static let background = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.07, green: 0.07, blue: 0.09, alpha: 1)
            : UIColor.white
    })

    static let cardBackground = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.15, green: 0.15, blue: 0.18, alpha: 1)
            : UIColor.white
    })

    static let success = Color(red: 0.20, green: 0.70, blue: 0.45)
    static let streak = Color.orange
    static let error = Color.red
    static let gold = Color(red: 0.85, green: 0.65, blue: 0.13)
    static let silver = Color(white: 0.6)
    static let bronze = Color(red: 0.72, green: 0.45, blue: 0.2)

    // MARK: - Redesign tokens (direction 2a)
    //
    // `accent` above now resolves to the same Forest green via AccentColor.colorset,
    // so most call sites can keep using it. These two exist only because "pressed" and
    // "wash" aren't expressible as a single asset-catalog color.
    static let accentPressed = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.09, green: 0.55, blue: 0.36, alpha: 1)
            : UIColor(red: 0.0, green: 0.376, blue: 0.22, alpha: 1)
    })

    static let accentWash = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.0, green: 0.498, blue: 0.29, alpha: 0.16)
            : UIColor(red: 0.953, green: 0.973, blue: 0.961, alpha: 1)
    })

    // Wireframe's "hairline" — native separator color, so it's correct in light and
    // dark automatically instead of a hardcoded grey.
    static let hairline = Color(uiColor: .separator)
}

private struct ScreenBackgroundModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(Theme.background.ignoresSafeArea())
    }
}

extension View {
    func screenBackground() -> some View { modifier(ScreenBackgroundModifier()) }
}

// MARK: - Redesign container (direction 2a)
//
// No shadow at rest, 12pt radius, and a border whose weight signals emphasis instead
// of a drop shadow — the up-next card (emphasized) vs. a dormant row (hairline) are the
// same shape, just a different border. Deliberately distinct from `.cardStyle()`, which
// the older, not-yet-redesigned screens still use.
private struct OutlinedContainerModifier: ViewModifier {
    var emphasized: Bool
    var fill: Color = Theme.cardBackground

    func body(content: Content) -> some View {
        content
            .background(fill, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(emphasized ? Color.primary.opacity(0.85) : Theme.hairline, lineWidth: emphasized ? 1.5 : 1)
            )
    }
}

extension View {
    func outlinedContainer(emphasized: Bool = false, fill: Color = Theme.cardBackground) -> some View {
        modifier(OutlinedContainerModifier(emphasized: emphasized, fill: fill))
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    // .disabled() alone doesn't grey out a custom ButtonStyle's own fill/text colors —
    // that has to be done explicitly, or a disabled button stays fully green (the "Lock
    // it in with nothing selected" bug).
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(isEnabled ? .white : Color(.tertiaryLabel))
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(isEnabled ? Theme.accent : Color(.systemGray5)))
            .opacity(configuration.isPressed ? 0.85 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

struct OutlineButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.primary)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.85), lineWidth: 1.5)
            )
            .opacity(configuration.isPressed ? 0.7 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}
