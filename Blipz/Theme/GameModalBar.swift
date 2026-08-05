import SwiftUI

/// The shared "✕ / GAME NAME / progress" bar every game screen uses instead of a
/// floating back chevron over a big title and subtitle.
struct GameModalBar<Trailing: View>: View {
    let title: String
    @ViewBuilder var trailing: () -> Trailing
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)
            }
            .frame(width: 44, height: 44, alignment: .leading)
            .contentShape(Rectangle())
            .accessibilityLabel("Close")

            Spacer()

            Text(title)
                .font(.subheadline.weight(.semibold))
                .tracking(1)
                .lineLimit(1)

            Spacer()

            trailing()
                .frame(width: 44, height: 44, alignment: .trailing)
        }
        .padding(.horizontal, 4)
    }
}

extension GameModalBar where Trailing == Color {
    init(title: String) {
        self.title = title
        self.trailing = { Color.clear }
    }
}
