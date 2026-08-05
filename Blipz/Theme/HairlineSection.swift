import SwiftUI

/// A plain 1px-divider list on the screen background — never a bordered/shadowed
/// card. Renders nothing when `items` is empty so it doesn't leave a stray divider.
struct HairlineSection<Item: Hashable, RowContent: View>: View {
    let items: [Item]
    @ViewBuilder var row: (Item) -> RowContent

    var body: some View {
        if !items.isEmpty {
            VStack(spacing: 0) {
                Divider()
                ForEach(items, id: \.self) { item in
                    row(item)
                    Divider()
                }
            }
        }
    }
}
