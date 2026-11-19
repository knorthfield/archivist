import AppKit
import CryptoKit

/// All the data of one copy: each pasteboard item, with the data of each of its types.
struct PasteboardContents: Equatable {
    struct Entry: Equatable {
        let type: String
        let data: Data
    }

    /// A type with more data than this is not kept.
    static let largestEntry = 50_000_000

    var items: [[Entry]]

    init(items: [[Entry]]) {
        self.items = items.filter { !$0.isEmpty }
    }

    init(text: String) {
        self.init(items: [[Entry(type: NSPasteboard.PasteboardType.string.rawValue, data: Data(text.utf8))]])
    }

    init(pasteboard: NSPasteboard) {
        self.init(items: (pasteboard.pasteboardItems ?? []).map { item in
            item.types.compactMap { type in
                guard let data = item.data(forType: type), data.count <= Self.largestEntry else { return nil }
                return Entry(type: type.rawValue, data: data)
            }
        })
    }

    var isEmpty: Bool { items.isEmpty }

    /// The text of each pasteboard item, one on each line.
    var plainText: String? {
        let texts = data(ofType: NSPasteboard.PasteboardType.string.rawValue).map { String(decoding: $0, as: UTF8.self) }
        return texts.isEmpty ? nil : texts.joined(separator: "\n")
    }

    var fileURLs: [URL] {
        data(ofType: NSPasteboard.PasteboardType.fileURL.rawValue).compactMap { data in
            // Finder can give a file reference URL (file:///.file/id=…): this changes it to a path.
            URL(dataRepresentation: data, relativeTo: nil).flatMap { ($0 as NSURL).filePathURL }
        }
    }

    var imageData: Data? {
        data(ofType: NSPasteboard.PasteboardType.png.rawValue).first
            ?? data(ofType: NSPasteboard.PasteboardType.tiff.rawValue).first
    }

    /// The same contents always give the same hash, so that a second copy is found.
    var hash: String {
        var hasher = SHA256()
        for item in items {
            for entry in item {
                hasher.update(data: Data(entry.type.utf8))
                hasher.update(data: entry.data)
            }
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    func write(to pasteboard: NSPasteboard) {
        pasteboard.clearContents()
        pasteboard.writeObjects(items.map { entries in
            let item = NSPasteboardItem()
            for entry in entries { item.setData(entry.data, forType: NSPasteboard.PasteboardType(entry.type)) }
            return item
        })
    }

    private func data(ofType type: String) -> [Data] {
        items.compactMap { item in item.first { $0.type == type }?.data }
    }
}
