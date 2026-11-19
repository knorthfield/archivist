import AppKit
@testable import Archivist

/// A folder, a clipboard and settings that only one test uses.
@MainActor
final class TestEnvironment {
    let root = FileManager.default.temporaryDirectory.appending(path: "ArchivistTests-\(UUID().uuidString)")
    let pasteboard = NSPasteboard(name: NSPasteboard.Name("ArchivistTests-\(UUID().uuidString)"))
    let defaults: UserDefaults
    private let defaultsName = "ArchivistTests-\(UUID().uuidString)"

    lazy var store = ItemStore(root: root)
    lazy var pinboards = PinboardStore(root: root)
    lazy var monitor = ClipboardMonitor(pasteboard: pasteboard, store: store, defaults: defaults)
    lazy var model = HistoryModel(store: store, pinboards: pinboards, monitor: monitor,
                                  pasteboard: pasteboard, defaults: defaults)

    init() {
        defaults = UserDefaults(suiteName: defaultsName)!
        Settings.registerDefaults(in: defaults)
    }

    isolated deinit {
        try? FileManager.default.removeItem(at: root)
        pasteboard.releaseGlobally()
        defaults.removePersistentDomain(forName: defaultsName)
    }

    func copy(_ text: String, markers: [String] = []) {
        let item = NSPasteboardItem()
        item.setString(text, forType: .string)
        for marker in markers { item.setData(Data(), forType: NSPasteboard.PasteboardType(marker)) }
        pasteboard.clearContents()
        pasteboard.writeObjects([item])
    }
}

let safari = SourceApp(bundleID: "com.apple.Safari", name: "Safari")
