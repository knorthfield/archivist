import SwiftUI

/// The small window on top of the panel, to edit an item or a pinboard.
struct ItemEditor: View {
    let model: HistoryModel
    let editor: HistoryModel.Editor

    @State private var text: String
    @State private var colour: PinboardColour
    @FocusState private var isFocused: Bool

    init(model: HistoryModel, editor: HistoryModel.Editor) {
        self.model = model
        self.editor = editor
        let (text, colour): (String, PinboardColour) = switch editor {
        case .text(let item): (item.text, .blue)
        case .title(let item): (item.title ?? "", .blue)
        case .pinboard(let pinboard): (pinboard.name, pinboard.colour)
        case .newItem, .newPinboard, .deletePinboard: ("", .blue)
        }
        _text = State(initialValue: text)
        _colour = State(initialValue: colour)
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.25)
                .onTapGesture { model.editor = nil }
            VStack(alignment: .leading, spacing: 10) {
                Text(heading).font(.headline)
                fields
                HStack {
                    Spacer()
                    Button("Cancel") { model.editor = nil }
                    Button(saveTitle, action: save)
                        .buttonStyle(.borderedProminent)
                }
            }
            .padding(14)
            .frame(width: 440)
            .background(.regularMaterial, in: .rect(cornerRadius: 12))
            .shadow(radius: 12)
        }
        .onAppear { isFocused = true }
    }

    private var heading: String {
        switch editor {
        case .text: "Edit Item"
        case .title: "Rename Item"
        case .newItem: "New Item"
        case .newPinboard: "New Pinboard"
        case .pinboard: "Edit Pinboard"
        case .deletePinboard(let pinboard): "Delete the pinboard “\(pinboard.name)”?"
        }
    }

    private var saveTitle: String {
        if case .deletePinboard = editor { "Delete" } else { "Save" }
    }

    @ViewBuilder
    private var fields: some View {
        switch editor {
        case .text, .newItem:
            TextEditor(text: $text)
                .font(.system(size: 12))
                .frame(height: 150)
                .focused($isFocused)
        case .title:
            TextField("Title", text: $text)
                .focused($isFocused)
                .onSubmit(save)
        case .newPinboard, .pinboard:
            TextField("Name", text: $text)
                .focused($isFocused)
                .onSubmit(save)
            HStack(spacing: 8) {
                ForEach(PinboardColour.allCases, id: \.self) { option in
                    Circle()
                        .fill(option.color)
                        .frame(width: 20, height: 20)
                        .overlay { Circle().strokeBorder(.primary, lineWidth: option == colour ? 2 : 0) }
                        .onTapGesture { colour = option }
                        .accessibilityLabel(option.rawValue)
                }
            }
        case .deletePinboard:
            Text("This also deletes the items in the pinboard.")
                .foregroundStyle(.secondary)
        }
    }

    private func save() {
        switch editor {
        case .text(let item): model.saveText(text, of: item)
        case .title(let item): model.saveTitle(text, of: item)
        case .newItem: model.addItem(text: text)
        case .newPinboard, .pinboard: model.savePinboard(name: text, colour: colour)
        case .deletePinboard(let pinboard): model.deletePinboard(pinboard)
        }
    }
}
