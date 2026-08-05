import SwiftUI

extension Font {
    /// Space Grotesk — the one display face, used only in the nine places the type
    /// system calls for (big scores, the masthead, the maths problem/timer). Everything
    /// else stays SF. Only Medium (500) and Bold (700) are bundled; any other weight
    /// falls back to Medium rather than silently requesting a file that isn't there.
    ///
    /// Scales with Dynamic Type via `relativeTo: .body` instead of a fixed point size,
    /// and always enables tabular figures — without it the maths timer and the animated
    /// score count-up jitter as digits change width.
    static func blipzDisplay(size: CGFloat, weight: Font.Weight) -> Font {
        let name = weight == .bold ? "SpaceGrotesk-Bold" : "SpaceGrotesk-Medium"
        return .custom(name, size: size, relativeTo: .body).monospacedDigit()
    }
}
