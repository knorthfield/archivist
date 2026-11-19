import AppKit
import Observation

/// The history. Each item is a folder in `Items` with a `metadata.json` and one file for each
/// pasteboard type.
@MainActor
@Observable
final class ItemStore {
    static let defaultRoot = URL.applicationSupportDirectory.appending(path: "Archivist")

    /// The newest item is first.
    private(set) var items: [ClipboardItem] = []

    @ObservationIgnored private let itemsFolder: URL
    /// Deleted items stay here until the next delete, so that the user can undo.
    @ObservationIgnored private let deletedFolder: URL
    @ObservationIgnored private var lastDeleted: [ClipboardItem] = []

    init(root: URL = ItemStore.defaultRoot) {
        itemsFolder = root.appending(path: "Items")
        deletedFolder = root.appending(path: "Deleted")
        try? FileManager.default.removeItem(at: deletedFolder)
        try? FileManager.default.createDirectory(at: itemsFolder, withIntermediateDirectories: true)
        let folders = (try? FileManager.default.contentsOfDirectory(at: itemsFolder, includingPropertiesForKeys: nil)) ?? []
        items = folders
            .compactMap { try? Data(contentsOf: $0.appending(path: "metadata.json")) }
            .compactMap { try? JSONDecoder().decode(ClipboardItem.self, from: $0) }
            .sorted { $0.date > $1.date }
    }

    func item(_ id: UUID) -> ClipboardItem? {
        items.first { $0.id == id }
    }

    /// Adds a copy to the front of the history. If the history has the same contents already,
    /// that item moves to the front.
    @discardableResult
    func add(_ contents: PasteboardContents, sourceApp: SourceApp?, date: Date = .now) -> ClipboardItem? {
        guard !contents.isEmpty else { return nil }
        let hash = contents.hash
        if let index = items.firstIndex(where: { $0.contentHash == hash }) {
            var item = items.remove(at: index)
            item.date = date
            items.insert(item, at: 0)
            saveMetadata(of: item)
            return item
        }
        let item = ClipboardItem(contents: contents, sourceApp: sourceApp, date: date)
        save(contents, of: item)
        items.insert(item, at: 0)
        return item
    }

    func contents(of item: ClipboardItem) -> PasteboardContents {
        PasteboardContents(items: item.types.enumerated().map { itemIndex, types in
            types.enumerated().compactMap { entryIndex, type in
                let url = dataFile(of: item, item: itemIndex, entry: entryIndex)
                return (try? Data(contentsOf: url)).map { PasteboardContents.Entry(type: type, data: $0) }
            }
        })
    }

    /// The file that Quick Look and drag and drop use for the item.
    func previewFile(of item: ClipboardItem) -> URL? {
        if let fileURL = item.fileURLs.first { return fileURL }
        let wanted: [NSPasteboard.PasteboardType] = item.kind == .image ? [.png, .tiff] : [.string]
        for (itemIndex, types) in item.types.enumerated() {
            for type in wanted {
                if let entryIndex = types.firstIndex(of: type.rawValue) {
                    return dataFile(of: item, item: itemIndex, entry: entryIndex)
                }
            }
        }
        return nil
    }

    func setTitle(_ title: String?, of id: UUID) {
        update(id) { $0.title = title?.isEmpty == true ? nil : title }
    }

    func setImageText(_ text: String?, of id: UUID) {
        update(id) { $0.imageText = text }
    }

    /// Replaces the contents of the item with plain text.
    func setText(_ text: String, of id: UUID) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        let contents = PasteboardContents(text: text)
        try? FileManager.default.removeItem(at: folder(of: items[index]))
        items[index].describe(contents)
        save(contents, of: items[index])
    }

    func delete(_ ids: Set<UUID>) {
        try? FileManager.default.removeItem(at: deletedFolder)
        try? FileManager.default.createDirectory(at: deletedFolder, withIntermediateDirectories: true)
        lastDeleted = items.filter { ids.contains($0.id) }
        for item in lastDeleted {
            try? FileManager.default.moveItem(at: folder(of: item), to: deletedFolder.appending(path: item.id.uuidString))
        }
        items.removeAll { ids.contains($0.id) }
    }

    /// Puts back the items of the last delete.
    @discardableResult
    func undoDelete() -> [ClipboardItem] {
        let restored = lastDeleted
        for item in restored {
            try? FileManager.default.moveItem(at: deletedFolder.appending(path: item.id.uuidString), to: folder(of: item))
        }
        lastDeleted = []
        items = (items + restored).sorted { $0.date > $1.date }
        return restored
    }

    /// Deletes the items from before the date, but not the items in `kept` (the pinned items).
    func deleteItems(olderThan date: Date, keeping kept: Set<UUID>) {
        let old = items.filter { $0.date < date && !kept.contains($0.id) }
        for item in old { try? FileManager.default.removeItem(at: folder(of: item)) }
        let oldIDs = Set(old.map(\.id))
        items.removeAll { oldIDs.contains($0.id) }
    }

    private func update(_ id: UUID, _ change: (inout ClipboardItem) -> Void) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        change(&items[index])
        saveMetadata(of: items[index])
    }

    private func folder(of item: ClipboardItem) -> URL {
        itemsFolder.appending(path: item.id.uuidString)
    }

    private func dataFile(of item: ClipboardItem, item itemIndex: Int, entry entryIndex: Int) -> URL {
        let type = item.types[itemIndex][entryIndex]
        return folder(of: item).appending(path: ClipboardItem.fileName(item: itemIndex, entry: entryIndex, type: type))
    }

    private func save(_ contents: PasteboardContents, of item: ClipboardItem) {
        try? FileManager.default.createDirectory(at: folder(of: item), withIntermediateDirectories: true)
        for (itemIndex, entries) in contents.items.enumerated() {
            for (entryIndex, entry) in entries.enumerated() {
                try? entry.data.write(to: dataFile(of: item, item: itemIndex, entry: entryIndex), options: .atomic)
            }
        }
        saveMetadata(of: item)
    }

    private func saveMetadata(of item: ClipboardItem) {
        guard let data = try? JSONEncoder().encode(item) else { return }
        try? data.write(to: folder(of: item).appending(path: "metadata.json"), options: .atomic)
    }
}
