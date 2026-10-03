import SwiftUI

extension Font {
    /// Native serif, scaled by Dynamic Type. Reserved for editorial/payoff headings.
    static let blipzEditorial = Font.system(.largeTitle, design: .serif)
}

struct BlipzWordmark: View {
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 1) {
            Text("blipz").font(.system(.title, design: .rounded, weight: .heavy))
            Image(systemName: "sparkle").font(.title3.weight(.light))
        }
        .foregroundStyle(Theme.brandInk)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Blipz")
    }
}

struct BlipzStreakPill: View {
    let streak: Int

    var body: some View {
        Label("\(streak) day streak", systemImage: "flame.fill")
            .font(.caption.weight(.semibold))
            .foregroundStyle(Theme.brandInk)
            .labelStyle(StreakLabelStyle())
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .premiumSurface(shadow: false)
    }

    private struct StreakLabelStyle: LabelStyle {
        func makeBody(configuration: Configuration) -> some View {
            HStack(spacing: 5) {
                configuration.icon.foregroundStyle(Theme.streak)
                configuration.title
            }
        }
    }
}

/// All competitive days are UTC, matching the backend. No invented Blip ordinal.
enum BlipzDay {
    static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    static func key(for date: Date = .now) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    static func label(for date: Date = .now) -> String {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.setLocalizedDateFormatFromTemplate("EEEE MMMM d")
        return formatter.string(from: date)
    }
}
