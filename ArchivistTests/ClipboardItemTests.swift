import AppKit
import Testing
@testable import Archivist

struct ClipboardItemTests {
    @Test(arguments: [
        ("Some words", ClipboardItem.Kind.text),
        ("https://example.com/page?x=1", .link),
        ("  https://example.com\n", .link),
        ("mailto:someone@example.com", .link),
        ("https://example.com and more", .text),
        ("example.com", .text),
        ("#fff", .colour),
        ("#1A2b3C", .colour),
        ("#11223344", .colour),
        ("#12345", .text),
        ("#ggg", .text),
    ])
    func theKindOfATextComesFromItsContent(text: String, kind: ClipboardItem.Kind) {
        #expect(ClipboardItem.kind(ofText: text) == kind)
    }

    @Test func aCopyOfFilesIsAFileItemWithThePaths() {
        let entries = ["/tmp/a.txt", "/tmp/b c.txt"].map { path in
            [PasteboardContents.Entry(type: NSPasteboard.PasteboardType.fileURL.rawValue,
                                      data: URL(filePath: path).dataRepresentation)]
        }
        let item = ClipboardItem(contents: PasteboardContents(items: entries), sourceApp: nil, date: .now)
        #expect(item.kind == .file)
        #expect(item.fileURLs.map(\.path) == ["/tmp/a.txt", "/tmp/b c.txt"])
    }

    @Test func aCopyOfAnImageIsAnImageItemWithItsSize() throws {
        let bitmap = try #require(NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: 4, pixelsHigh: 3, bitsPerSample: 8, samplesPerPixel: 4,
            hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0))
        let png = try #require(bitmap.representation(using: .png, properties: [:]))
        let contents = PasteboardContents(items: [[.init(type: NSPasteboard.PasteboardType.png.rawValue, data: png)]])
        let item = ClipboardItem(contents: contents, sourceApp: nil, date: .now)
        #expect(item.kind == .image)
        #expect(item.imageWidth == 4)
        #expect(item.imageHeight == 3)
    }

    @Test func searchLooksInTheTitleTheTextTheAppAndTheImageText() {
        var item = ClipboardItem(contents: PasteboardContents(text: "Café menu"), sourceApp: safari, date: .now)
        item.title = "Lunch"
        item.imageText = "Invoice 42"
        #expect(item.matches("cafe"))
        #expect(item.matches("lunch"))
        #expect(item.matches("safari"))
        #expect(item.matches("invoice"))
        #expect(!item.matches("dinner"))
    }

    @Test func theSameContentsGiveTheSameHash() {
        #expect(PasteboardContents(text: "a").hash == PasteboardContents(text: "a").hash)
        #expect(PasteboardContents(text: "a").hash != PasteboardContents(text: "b").hash)
    }
}
