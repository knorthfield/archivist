import AppKit
import UniformTypeIdentifiers

/// The app that was at the front when the user made the copy.
struct SourceApp: Equatable {
    let bundleID: String
    let name: String

    static let archivist = SourceApp(bundleID: Bundle.main.bundleIdentifier ?? "Archivist", name: "Archivist")
}

/// One copy in the history. This is the `metadata.json` of the item; its data is in files
/// in the same folder.
struct ClipboardItem: Codable, Identifiable, Hashable {
    enum Kind: String, Codable {
        case text, link, image, file, colour

        var name: String {
            switch self {
            case .text: "Text"
            case .link: "Link"
            case .image: "Image"
            case .file: "File"
            case .colour: "Colour"
            }
        }
    }

    let id: UUID
    var date: Date
    var sourceAppBundleID: String?
    var sourceAppName: String?
    var kind: Kind
    var title: String?
    /// The text for the preview and for the search. For files, it is the paths.
    var text: String
    /// The text that Vision found in an image.
    var imageText: String?
    var imageWidth: Int?
    var imageHeight: Int?
    var contentHash: String
    /// The pasteboard types of each pasteboard item, in the sequence of the data files.
    var types: [[String]]

    init(contents: PasteboardContents, sourceApp: SourceApp?, date: Date) {
        id = UUID()
        self.date = date
        sourceAppBundleID = sourceApp?.bundleID
        sourceAppName = sourceApp?.name
        kind = .text
        text = ""
        contentHash = ""
        types = []
        describe(contents)
    }

    /// Sets the properties that come from the contents.
    mutating func describe(_ contents: PasteboardContents) {
        contentHash = contents.hash
        types = contents.items.map { $0.map(\.type) }
        imageWidth = nil
        imageHeight = nil
        let fileURLs = contents.fileURLs
        let plainText = contents.plainText
        if !fileURLs.isEmpty {
            kind = .file
            text = fileURLs.map(\.path).joined(separator: "\n")
        } else if let plainText {
            kind = Self.kind(ofText: plainText)
            text = plainText
        } else if let imageData = contents.imageData {
            kind = .image
            text = ""
            if let image = NSBitmapImageRep(data: imageData) {
                imageWidth = image.pixelsWide
                imageHeight = image.pixelsHigh
            }
        } else {
            kind = .text
            text = ""
        }
    }

    static func kind(ofText text: String) -> Kind {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.wholeMatch(of: /#([0-9a-fA-F]{3}|[0-9a-fA-F]{6}|[0-9a-fA-F]{8})/) != nil { return .colour }
        if !trimmed.contains(where: \.isWhitespace), let url = URL(string: trimmed) {
            let scheme = url.scheme?.lowercased()
            if scheme == "mailto" || ((scheme == "http" || scheme == "https") && url.host() != nil) { return .link }
        }
        return .text
    }

    /// The name of the data file of one type. The extension lets Quick Look show the file.
    static func fileName(item: Int, entry: Int, type: String) -> String {
        let name = "\(item)-\(entry)"
        let uniformType = UTType(type)
        // The plain text type of the clipboard has no extension of its own.
        let plainTextExtension = uniformType?.conforms(to: .plainText) == true ? "txt" : nil
        guard let fileExtension = uniformType?.preferredFilenameExtension ?? plainTextExtension else { return name }
        return "\(name).\(fileExtension)"
    }

    var fileURLs: [URL] {
        kind == .file ? text.split(separator: "\n").map { URL(filePath: String($0)) } : []
    }

    /// Search looks in the title, the text, the name of the source app and the text in an image.
    func matches(_ query: String) -> Bool {
        [title, text, sourceAppName, imageText].contains { $0?.localizedStandardContains(query) == true }
    }
}
