import AppKit
import Carbon.HIToolbox
import Observation

/// The state of the history panel, and the actions of its keys and buttons.
@MainActor
@Observable
final class HistoryModel {
    /// The small window on top of the panel.
    enum Editor: Hashable {
        case text(ClipboardItem)
        case title(ClipboardItem)
        case newItem
        case newPinboard
        case pinboard(Pinboard)
        case deletePinboard(Pinboard)
    }

    enum SelectionMode {
        case replace, toggle, range
    }

    let store: ItemStore
    let pinboards: PinboardStore
    let monitor: ClipboardMonitor

    var query = "" {
        didSet { selectFirstItem() }
    }
    /// `nil` shows the full history.
    var selectedPinboardID: UUID? {
        didSet { selectFirstItem() }
    }
    private(set) var selection: Set<UUID> = []
    /// The item that the arrow keys move from.
    private(set) var cursor: UUID?
    var editor: Editor?
    private(set) var hasAccessibility = true
    /// The time when the panel opened. The cards show the age of the items at this time.
    private(set) var shownAt = Date.now

    @ObservationIgnored var draggedItemIDs: [UUID] = []
    @ObservationIgnored var draggedPinboardID: UUID?
    @ObservationIgnored var hidePanel: () -> Void = {}
    @ObservationIgnored var showSettings: () -> Void = {}
    @ObservationIgnored var showQuickLook: ([URL]) -> Void = { _ in }
    @ObservationIgnored private var selectionAnchor: UUID?
    /// The pinboard of each item of the last delete, for undo.
    @ObservationIgnored private var pinboardOfDeletedItem: [UUID: UUID] = [:]
    @ObservationIgnored private let pasteboard: NSPasteboard
    @ObservationIgnored private let defaults: UserDefaults

    init(store: ItemStore, pinboards: PinboardStore, monitor: ClipboardMonitor,
         pasteboard: NSPasteboard = .general, defaults: UserDefaults = .standard) {
        self.store = store
        self.pinboards = pinboards
        self.monitor = monitor
        self.pasteboard = pasteboard
        self.defaults = defaults
    }

    /// A search looks in all the items. Without a search, the list is the history or one pinboard.
    var visibleItems: [ClipboardItem] {
        if !query.isEmpty { return store.items.filter { $0.matches(query) } }
        guard let selectedPinboardID, let pinboard = pinboards.pinboard(selectedPinboardID) else { return store.items }
        return pinboard.itemIDs.compactMap(store.item)
    }

    var selectedItems: [ClipboardItem] {
        visibleItems.filter { selection.contains($0.id) }
    }

    func prepareToShow() {
        editor = nil
        draggedItemIDs = []
        draggedPinboardID = nil
        hasAccessibility = Permissions.hasAccessibility
        shownAt = .now
        query = ""
        selectedPinboardID = nil
    }

    // MARK: Selection

    func select(_ id: UUID, mode: SelectionMode = .replace) {
        let items = visibleItems
        switch mode {
        case .replace:
            selection = [id]
            selectionAnchor = id
        case .toggle:
            selection.formSymmetricDifference([id])
            selectionAnchor = id
        case .range:
            guard let from = items.firstIndex(where: { $0.id == selectionAnchor }),
                  let to = items.firstIndex(where: { $0.id == id }) else { return select(id) }
            selection = Set(items[min(from, to)...max(from, to)].map(\.id))
        }
        cursor = id
    }

    func selectAll() {
        selection = Set(visibleItems.map(\.id))
    }

    func moveCursor(by offset: Int, extending: Bool = false) {
        let items = visibleItems
        guard !items.isEmpty else { return }
        let current = items.firstIndex { $0.id == cursor } ?? (offset > 0 ? -1 : items.count)
        let index = min(max(current + offset, 0), items.count - 1)
        select(items[index].id, mode: extending ? .range : .replace)
    }

    private func selectFirstItem() {
        if let first = visibleItems.first {
            select(first.id)
        } else {
            selection = []
            cursor = nil
            selectionAnchor = nil
        }
    }

    // MARK: Paste and copy

    /// The data that goes on the clipboard for the items. Text items go together as one text.
    func contents(toPaste items: [ClipboardItem], asPlainText: Bool) -> PasteboardContents {
        let text = items.map(\.text).filter { !$0.isEmpty }.joined(separator: "\n")
        let isAllText = items.allSatisfy { $0.kind != .image && $0.kind != .file }
        if !text.isEmpty, asPlainText || (items.count > 1 && isAllText) {
            return PasteboardContents(text: text)
        }
        return PasteboardContents(items: items.flatMap { store.contents(of: $0).items })
    }

    func copy(_ items: [ClipboardItem], asPlainText: Bool = false) {
        guard !items.isEmpty else { return }
        contents(toPaste: items, asPlainText: asPlainText).write(to: pasteboard)
        monitor.ignoreCurrentContents()
    }

    /// Puts the items on the clipboard and presses ⌘V in the app at the front. Without the
    /// Accessibility permission, the items only go on the clipboard.
    func paste(_ items: [ClipboardItem], asPlainText: Bool = false) {
        guard !items.isEmpty else { return }
        copy(items, asPlainText: asPlainText)
        hidePanel()
        guard Permissions.hasAccessibility else { return }
        Task {
            // The app at the front needs a moment to get the keyboard back.
            try? await Task.sleep(for: .milliseconds(100))
            Paster.pressCommandV()
        }
    }

    func quickPaste(_ number: Int, asPlainText: Bool) {
        let items = visibleItems
        guard items.indices.contains(number - 1) else { return }
        paste([items[number - 1]], asPlainText: asPlainText)
    }

    func open(_ items: [ClipboardItem]) {
        let urls = items.flatMap { item in
            item.kind == .link ? [URL(string: item.text.trimmingCharacters(in: .whitespacesAndNewlines))].compactMap { $0 } : item.fileURLs
        }
        guard !urls.isEmpty else { return }
        hidePanel()
        for url in urls { NSWorkspace.shared.open(url) }
    }

    // MARK: Delete

    func delete(_ items: [ClipboardItem]) {
        guard !items.isEmpty else { return }
        let ids = Set(items.map(\.id))
        let visible = visibleItems
        let next = visible.firstIndex { ids.contains($0.id) }
            .flatMap { index in visible[index...].first { !ids.contains($0.id) } ?? visible[..<index].last }
        pinboardOfDeletedItem = Dictionary(uniqueKeysWithValues: ids.compactMap { id in
            pinboards.pinboard(with: id).map { (id, $0.id) }
        })
        pinboards.unpin(ids)
        store.delete(ids)
        if let next { select(next.id) } else { selectFirstItem() }
    }

    func undoDelete() {
        let restored = store.undoDelete()
        for item in restored {
            if let pinboardID = pinboardOfDeletedItem[item.id] { pinboards.pin([item.id], to: pinboardID) }
        }
        pinboardOfDeletedItem = [:]
        if let first = restored.first { select(first.id) }
    }

    func deleteOldItems(now: Date = .now) {
        let retention = defaults.string(forKey: Settings.keepHistory).flatMap(HistoryRetention.init) ?? .month
        guard let cutOff = retention.cutOff(from: now) else { return }
        store.deleteItems(olderThan: cutOff, keeping: pinboards.pinnedIDs)
    }

    func clearHistory() {
        store.deleteItems(olderThan: .distantFuture, keeping: pinboards.pinnedIDs)
        selectFirstItem()
    }

    // MARK: Edit

    func saveText(_ text: String, of item: ClipboardItem) {
        store.setText(text, of: item.id)
        editor = nil
    }

    func saveTitle(_ title: String, of item: ClipboardItem) {
        store.setTitle(title, of: item.id)
        editor = nil
    }

    func addItem(text: String) {
        editor = nil
        guard !text.isEmpty, let item = store.add(PasteboardContents(text: text), sourceApp: .archivist) else { return }
        if let selectedPinboardID { pinboards.pin([item.id], to: selectedPinboardID) }
        select(item.id)
    }

    // MARK: Pinboards

    func savePinboard(name: String, colour: PinboardColour) {
        let name = name.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        if case .pinboard(let pinboard) = editor {
            pinboards.update(pinboard.id, name: name, colour: colour)
        } else {
            selectedPinboardID = pinboards.add(name: name, colour: colour).id
        }
        editor = nil
    }

    /// Deletes the pinboard and the items in it.
    func deletePinboard(_ pinboard: Pinboard) {
        if selectedPinboardID == pinboard.id { selectedPinboardID = nil }
        let itemIDs = Set(pinboards.pinboard(pinboard.id)?.itemIDs ?? [])
        pinboards.delete(pinboard.id)
        pinboardOfDeletedItem = [:]
        store.delete(itemIDs)
        editor = nil
        selectFirstItem()
    }

    func showPinboard(offset: Int) {
        let ids: [UUID?] = [nil] + pinboards.pinboards.map(\.id)
        let index = (ids.firstIndex(of: selectedPinboardID) ?? 0) + offset
        selectedPinboardID = ids[(index + ids.count) % ids.count]
    }

    func togglePause() {
        if monitor.isPaused { monitor.resume() } else { monitor.pause(until: .distantFuture) }
    }

    // MARK: Drag and drop

    /// The items that a drag of this item moves: the selection, if the item is in it.
    func startDrag(of item: ClipboardItem) {
        draggedPinboardID = nil
        draggedItemIDs = selection.contains(item.id) ? selectedItems.map(\.id) : [item.id]
    }

    func dropOnPinboard(_ pinboard: Pinboard) -> Bool {
        if let draggedPinboardID {
            pinboards.move(draggedPinboardID, toPositionOf: pinboard.id)
        } else if !draggedItemIDs.isEmpty {
            pinboards.pin(draggedItemIDs, to: pinboard.id)
        } else {
            return false
        }
        draggedPinboardID = nil
        draggedItemIDs = []
        return true
    }

    /// In a pinboard, a drop on a card moves the dragged item to that position.
    func dropOnItem(_ item: ClipboardItem) -> Bool {
        guard query.isEmpty, selectedPinboardID != nil, let dragged = draggedItemIDs.first, dragged != item.id else { return false }
        pinboards.moveItem(dragged, toPositionOf: item.id)
        draggedItemIDs = []
        return true
    }

    // MARK: Keys

    private static let digitKeys = [kVK_ANSI_1, kVK_ANSI_2, kVK_ANSI_3, kVK_ANSI_4, kVK_ANSI_5,
                                    kVK_ANSI_6, kVK_ANSI_7, kVK_ANSI_8, kVK_ANSI_9]

    /// Returns `true` if the key did something, so that the panel does not use the key again.
    func handleKeyDown(_ event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection([.command, .shift, .option, .control])
        let hasCommand = flags.contains(.command)
        let hasShift = flags.contains(.shift)
        let keyCode = Int(event.keyCode)
        let character = event.charactersIgnoringModifiers?.lowercased() ?? ""

        if editor != nil { return handleEditorKeyDown(keyCode: keyCode, character: character, hasCommand: hasCommand, hasShift: hasShift) }

        if hasCommand, let digit = Self.digitKeys.firstIndex(of: keyCode) {
            quickPaste(digit + 1, asPlainText: hasShift)
            return true
        }
        switch keyCode {
        case kVK_Escape:
            if query.isEmpty { hidePanel() } else { query = "" }
        case kVK_LeftArrow:
            if hasCommand { showPinboard(offset: -1) } else { moveCursor(by: -1, extending: hasShift) }
        case kVK_RightArrow:
            if hasCommand { showPinboard(offset: 1) } else { moveCursor(by: 1, extending: hasShift) }
        case kVK_UpArrow where hasCommand:
            moveCursor(by: -visibleItems.count)
        case kVK_DownArrow where hasCommand:
            moveCursor(by: visibleItems.count)
        case kVK_Return, kVK_ANSI_KeypadEnter:
            paste(selectedItems, asPlainText: hasShift)
        case kVK_Space where query.isEmpty:
            showQuickLook(selectedItems.compactMap(store.previewFile))
        case kVK_Delete:
            if query.isEmpty { delete(selectedItems) } else { query.removeLast() }
        default:
            if hasCommand { return handleCommandKey(character, hasShift: hasShift) }
            guard !flags.contains(.control), let characters = event.characters, !characters.isEmpty,
                  characters.unicodeScalars.allSatisfy(Self.isSearchCharacter) else { return false }
            query += characters
        }
        return true
    }

    private func handleCommandKey(_ character: String, hasShift: Bool) -> Bool {
        switch character {
        case "a": selectAll()
        case "c": copy(selectedItems)
        case "o": open(selectedItems)
        case "e": if let item = selectedItems.first, item.kind != .image, item.kind != .file { editor = .text(item) }
        case "r": if let item = selectedItems.first { editor = .title(item) }
        case "n": editor = hasShift ? .newPinboard : .newItem
        case "z": undoDelete()
        case "t": togglePause()
        case "f": break
        case ",": hidePanel(); showSettings()
        case "q": NSApp.terminate(nil)
        default: return false
        }
        return true
    }

    /// The app has no Edit menu, thus the text fields of the editor do not get ⌘X, ⌘C, ⌘V, ⌘A and ⌘Z.
    private func handleEditorKeyDown(keyCode: Int, character: String, hasCommand: Bool, hasShift: Bool) -> Bool {
        if keyCode == kVK_Escape {
            editor = nil
            return true
        }
        guard hasCommand else { return false }
        let action: Selector? = switch character {
        case "x": #selector(NSText.cut(_:))
        case "c": #selector(NSText.copy(_:))
        case "v": #selector(NSText.paste(_:))
        case "a": #selector(NSText.selectAll(_:))
        case "z": Selector((hasShift ? "redo:" : "undo:"))
        default: nil
        }
        guard let action else { return false }
        NSApp.sendAction(action, to: nil, from: nil)
        // A copy in the editor is not a new item.
        monitor.ignoreCurrentContents()
        return true
    }

    /// Not a control character, and not a function key (arrows, F1…).
    private static func isSearchCharacter(_ scalar: Unicode.Scalar) -> Bool {
        scalar.properties.generalCategory != .control && !(0xF700...0xF8FF).contains(scalar.value)
    }
}
