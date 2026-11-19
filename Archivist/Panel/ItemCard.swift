import SwiftUI

/// One item of the history: a header with the kind, the age and the source app, a preview, and
/// a footer with the size.
struct ItemCard: View {
    let model: HistoryModel
    let item: ClipboardItem
    let quickPasteNumber: Int?

    private var isSelected: Bool { model.selection.contains(item.id) }

    var body: some View {
        VStack(spacing: 0) {
            header
            preview
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .clipped()
            footer
        }
        .frame(width: 230)
        .background(Color(nsColor: .textBackgroundColor))
        .clipShape(.rect(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(isSelected ? Color.accentColor : Color.primary.opacity(0.1), lineWidth: isSelected ? 3 : 1)
        }
        .contentShape(.rect(cornerRadius: 12))
        .onTapGesture(perform: click)
        .contextMenu { menu }
        .onDrag {
            model.startDrag(of: item)
            return dragProvider
        }
        .onDrop(of: [.item], isTargeted: nil) { _ in model.dropOnItem(item) }
    }

    private var header: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 1) {
                Text(item.title ?? item.kind.name)
                    .font(.headline)
                    .lineLimit(1)
                Text(RelativeDateTimeFormatter().localizedString(for: item.date, relativeTo: max(model.shownAt, item.date)))
                    .font(.caption)
                    .opacity(0.85)
            }
            Spacer(minLength: 0)
            if let icon = CardImages.appIcon(of: item.sourceAppBundleID) {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 32, height: 32)
                    .help(item.sourceAppName ?? "")
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(pinboardColour ?? item.kind.color)
    }

    private var pinboardColour: Color? {
        model.pinboards.pinboard(with: item.id)?.colour.color
    }

    @ViewBuilder
    private var preview: some View {
        switch item.kind {
        case .text:
            Text(item.text.prefix(600))
                .font(.system(size: 11))
                .padding(8)
        case .link:
            VStack(alignment: .leading, spacing: 6) {
                Label(URL(string: item.text)?.host() ?? "Link", systemImage: "link")
                    .font(.headline)
                    .lineLimit(1)
                Text(item.text)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            .padding(8)
        case .image:
            if let image = CardImages.thumbnail(of: item, in: model.store) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(6)
            }
        case .file:
            VStack(spacing: 6) {
                if let first = item.fileURLs.first {
                    Image(nsImage: NSWorkspace.shared.icon(forFile: first.path))
                        .resizable()
                        .scaledToFit()
                        .frame(height: 64)
                }
                Text(item.fileURLs.map(\.lastPathComponent).joined(separator: "\n"))
                    .font(.system(size: 11))
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(8)
        case .colour:
            ZStack {
                Color(hex: item.text) ?? .clear
                Text(item.text.trimmingCharacters(in: .whitespacesAndNewlines))
                    .font(.system(.title3, design: .monospaced))
                    .padding(6)
                    .background(.regularMaterial, in: .rect(cornerRadius: 6))
            }
        }
    }

    private var footer: some View {
        HStack {
            Text(footerText)
            Spacer()
            if let quickPasteNumber {
                Text("⌘\(quickPasteNumber)")
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
    }

    private var footerText: String {
        switch item.kind {
        case .image:
            if let width = item.imageWidth, let height = item.imageHeight { "\(width) × \(height)" } else { "Image" }
        case .file:
            item.fileURLs.count == 1 ? "1 file" : "\(item.fileURLs.count) files"
        default:
            item.text.count == 1 ? "1 character" : "\(item.text.count) characters"
        }
    }

    @ViewBuilder
    private var menu: some View {
        let items = targetItems
        Button("Paste") { model.paste(items) }
        Button("Paste as Plain Text") { model.paste(items, asPlainText: true) }
        Button("Copy") { model.copy(items) }
        if item.kind == .link || item.kind == .file {
            Button("Open") { model.open(items) }
        }
        Divider()
        Menu("Pin to") {
            ForEach(model.pinboards.pinboards) { pinboard in
                Button(pinboard.name) { model.pinboards.pin(items.map(\.id), to: pinboard.id) }
            }
            if !model.pinboards.pinboards.isEmpty { Divider() }
            Button("New Pinboard…") { model.editor = .newPinboard }
        }
        if model.pinboards.pinboard(with: item.id) != nil {
            Button("Unpin") { model.pinboards.unpin(Set(items.map(\.id))) }
        }
        Divider()
        Button("Rename…") { model.editor = .title(item) }
        if item.kind != .image && item.kind != .file {
            Button("Edit…") { model.editor = .text(item) }
        }
        Divider()
        Button("Delete", role: .destructive) { model.delete(items) }
    }

    /// A menu command is for the selection if the card is in it, and for the card alone if not.
    private var targetItems: [ClipboardItem] {
        isSelected ? model.selectedItems : [item]
    }

    private func click() {
        let event = NSApp.currentEvent
        let flags = event?.modifierFlags ?? []
        if flags.contains(.command) {
            model.select(item.id, mode: .toggle)
        } else if flags.contains(.shift) {
            model.select(item.id, mode: .range)
        } else if event?.clickCount == 2 {
            model.paste([item])
        } else {
            model.select(item.id)
        }
    }

    private var dragProvider: NSItemProvider {
        switch item.kind {
        case .image, .file:
            model.store.previewFile(of: item).flatMap { NSItemProvider(contentsOf: $0) } ?? NSItemProvider()
        case .link:
            URL(string: item.text).map { NSItemProvider(object: $0 as NSURL) } ?? NSItemProvider(object: item.text as NSString)
        case .text, .colour:
            NSItemProvider(object: item.text as NSString)
        }
    }
}

/// The app icons and the small images of the cards. A card gets them many times.
@MainActor
enum CardImages {
    private static var appIcons: [String: NSImage] = [:]
    private static let thumbnails = NSCache<NSUUID, NSImage>()

    static func appIcon(of bundleID: String?) -> NSImage? {
        guard let bundleID else { return nil }
        if let icon = appIcons[bundleID] { return icon }
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else { return nil }
        let icon = NSWorkspace.shared.icon(forFile: url.path)
        appIcons[bundleID] = icon
        return icon
    }

    static func thumbnail(of item: ClipboardItem, in store: ItemStore) -> NSImage? {
        if let image = thumbnails.object(forKey: item.id as NSUUID) { return image }
        guard let url = store.previewFile(of: item),
              let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: 600,
        ]
        guard let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        let image = NSImage(cgImage: thumbnail, size: .zero)
        thumbnails.setObject(image, forKey: item.id as NSUUID)
        return image
    }
}

extension ClipboardItem.Kind {
    var color: Color {
        switch self {
        case .text: .blue
        case .link: .teal
        case .image: .pink
        case .file: .orange
        case .colour: .indigo
        }
    }
}

extension Color {
    /// "#RGB", "#RRGGBB" or "#RRGGBBAA".
    init?(hex: String) {
        var digits = Array(hex.trimmingCharacters(in: .whitespacesAndNewlines).dropFirst())
        if digits.count == 3 { digits = digits.flatMap { [$0, $0] } }
        if digits.count == 6 { digits += ["f", "f"] }
        guard digits.count == 8, let value = UInt32(String(digits), radix: 16) else { return nil }
        self.init(.sRGB,
                  red: Double(value >> 24 & 0xFF) / 255,
                  green: Double(value >> 16 & 0xFF) / 255,
                  blue: Double(value >> 8 & 0xFF) / 255,
                  opacity: Double(value & 0xFF) / 255)
    }
}
