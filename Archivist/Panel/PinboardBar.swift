import SwiftUI

/// The top row of the panel: the search text, the history tab, the pinboard tabs and the buttons.
struct PinboardBar: View {
    let model: HistoryModel

    var body: some View {
        HStack(spacing: 8) {
            searchText
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    Tab(title: "Clipboard", colour: nil, isSelected: model.selectedPinboardID == nil && model.query.isEmpty) {
                        model.query = ""
                        model.selectedPinboardID = nil
                    }
                    ForEach(model.pinboards.pinboards) { pinboard in
                        pinboardTab(pinboard)
                    }
                    Button("New Pinboard", systemImage: "plus") { model.editor = .newPinboard }
                        .labelStyle(.iconOnly)
                        .buttonStyle(.borderless)
                        .help("New pinboard (⇧⌘N)")
                }
            }
            Spacer()
            Button(model.monitor.isPaused ? "Resume" : "Pause", systemImage: model.monitor.isPaused ? "play.fill" : "pause.fill") {
                model.togglePause()
            }
            .help(model.monitor.isPaused ? "Archivist is paused. Click to save copies again (⌘T)." : "Pause: do not save copies (⌘T)")
            Button("Settings", systemImage: "gear") {
                model.hidePanel()
                model.showSettings()
            }
            .help("Settings (⌘,)")
        }
        .labelStyle(.iconOnly)
        .buttonStyle(.borderless)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    /// Not a text field: the panel adds the keys that the user types to the search.
    private var searchText: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            Text(model.query.isEmpty ? "Type to search" : model.query)
                .foregroundStyle(model.query.isEmpty ? .secondary : .primary)
                .lineLimit(1)
            Spacer(minLength: 0)
            if !model.query.isEmpty {
                Button("Clear", systemImage: "xmark.circle.fill") { model.query = "" }
                    .labelStyle(.iconOnly)
                    .buttonStyle(.borderless)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .frame(width: 220)
        .background(.quaternary, in: .rect(cornerRadius: 8))
    }

    private func pinboardTab(_ pinboard: Pinboard) -> some View {
        Tab(title: pinboard.name, colour: pinboard.colour.color,
            isSelected: model.selectedPinboardID == pinboard.id && model.query.isEmpty) {
            model.query = ""
            model.selectedPinboardID = pinboard.id
        }
        .contextMenu {
            Button("Edit…") { model.editor = .pinboard(pinboard) }
            Button("Delete…", role: .destructive) { model.editor = .deletePinboard(pinboard) }
        }
        .onDrag {
            model.draggedItemIDs = []
            model.draggedPinboardID = pinboard.id
            return NSItemProvider(object: pinboard.name as NSString)
        }
        .onDrop(of: [.item], isTargeted: nil) { _ in model.dropOnPinboard(pinboard) }
    }
}

private struct Tab: View {
    let title: String
    let colour: Color?
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                if let colour {
                    Circle().fill(colour).frame(width: 8, height: 8)
                }
                Text(title).lineLimit(1)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(isSelected ? AnyShapeStyle(.selection) : AnyShapeStyle(.clear), in: .capsule)
            .contentShape(.capsule)
        }
        .buttonStyle(.plain)
    }
}

extension PinboardColour {
    var color: Color {
        switch self {
        case .red: .red
        case .orange: .orange
        case .yellow: .yellow
        case .green: .green
        case .blue: .blue
        case .purple: .purple
        case .pink: .pink
        case .grey: .gray
        }
    }
}
