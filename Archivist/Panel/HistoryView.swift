import SwiftUI

struct HistoryView: View {
    let model: HistoryModel

    var body: some View {
        VStack(spacing: 0) {
            PinboardBar(model: model)
            if !model.hasAccessibility {
                accessibilityHint
            }
            cards
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.regularMaterial)
        .clipShape(UnevenRoundedRectangle(topLeadingRadius: 14, topTrailingRadius: 14))
        .overlay {
            if let editor = model.editor {
                ItemEditor(model: model, editor: editor)
                    // A new editor starts with the values of its item.
                    .id(editor)
            }
        }
    }

    private var accessibilityHint: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.yellow)
            Text("Archivist can only copy an item to the clipboard. To paste into the app at the front, it needs the Accessibility permission.")
            Button("Allow…") { Permissions.requestAccessibility() }
        }
        .font(.callout)
        .padding(.bottom, 8)
    }

    @ViewBuilder
    private var cards: some View {
        let items = model.visibleItems
        if items.isEmpty {
            Text(model.query.isEmpty ? "Nothing here yet. Copy something." : "No items match “\(model.query)”.")
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollViewReader { proxy in
                ScrollView(.horizontal) {
                    LazyHStack(spacing: 12) {
                        ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                            ItemCard(model: model, item: item, quickPasteNumber: index < 9 ? index + 1 : nil)
                                .id(item.id)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                }
                .onChange(of: model.cursor) { _, cursor in
                    guard let cursor else { return }
                    withAnimation(.easeOut(duration: 0.15)) { proxy.scrollTo(cursor) }
                }
            }
        }
    }
}
