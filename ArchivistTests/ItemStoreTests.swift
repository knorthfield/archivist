import AppKit
import Testing
@testable import Archivist

@MainActor
struct ItemStoreTests {
    let environment = TestEnvironment()
    var store: ItemStore { environment.store }

    @Test func anItemAndItsDataStayAfterARestart() throws {
        let contents = PasteboardContents(items: [[
            .init(type: "public.utf8-plain-text", data: Data("Hello".utf8)),
            .init(type: "public.rtf", data: Data("{\\rtf1 Hello}".utf8)),
        ]])
        let item = try #require(store.add(contents, sourceApp: safari))
        store.setTitle("Greeting", of: item.id)

        let reopened = ItemStore(root: environment.root)
        let saved = try #require(reopened.items.first)
        #expect(reopened.items.count == 1)
        #expect(saved.title == "Greeting")
        #expect(saved.sourceAppName == "Safari")
        #expect(reopened.contents(of: saved) == contents)
    }

    @Test func theNewestItemIsFirst() {
        store.add(PasteboardContents(text: "old"), sourceApp: nil, date: Date(timeIntervalSince1970: 1))
        store.add(PasteboardContents(text: "new"), sourceApp: nil, date: Date(timeIntervalSince1970: 2))
        #expect(store.items.map(\.text) == ["new", "old"])
        #expect(ItemStore(root: environment.root).items.map(\.text) == ["new", "old"])
    }

    @Test func asecondCopyOfTheSameContentsMovesTheItemToTheFront() {
        let first = store.add(PasteboardContents(text: "a"), sourceApp: nil)
        store.add(PasteboardContents(text: "b"), sourceApp: nil)
        let again = store.add(PasteboardContents(text: "a"), sourceApp: nil)
        #expect(store.items.map(\.text) == ["a", "b"])
        #expect(again?.id == first?.id)
    }

    @Test func emptyContentsAreNotSaved() {
        #expect(store.add(PasteboardContents(items: []), sourceApp: nil) == nil)
        #expect(store.items.isEmpty)
    }

    @Test func deleteRemovesTheItemAndUndoPutsItBack() throws {
        let item = try #require(store.add(PasteboardContents(text: "a"), sourceApp: nil))
        store.delete([item.id])
        #expect(store.items.isEmpty)
        #expect(ItemStore.init(root: environment.root).items.isEmpty == true)

        // The line above made a new store, which empties the folder of deleted items.
        let other = try #require(store.add(PasteboardContents(text: "b"), sourceApp: nil))
        store.delete([other.id])
        store.undoDelete()
        #expect(store.items.map(\.text) == ["b"])
        #expect(store.contents(of: other).plainText == "b")
    }

    @Test func oldItemsAreDeletedButNotPinnedItems() throws {
        let old = try #require(store.add(PasteboardContents(text: "old"), sourceApp: nil, date: Date(timeIntervalSince1970: 1)))
        let pinned = try #require(store.add(PasteboardContents(text: "pinned"), sourceApp: nil, date: Date(timeIntervalSince1970: 2)))
        store.add(PasteboardContents(text: "new"), sourceApp: nil, date: Date(timeIntervalSince1970: 100))
        store.deleteItems(olderThan: Date(timeIntervalSince1970: 50), keeping: [pinned.id])
        #expect(store.items.map(\.text) == ["new", "pinned"])
        #expect(store.item(old.id) == nil)
        #expect(ItemStore(root: environment.root).items.count == 2)
    }

    @Test func anEditReplacesTheContentsWithPlainText() throws {
        let item = try #require(store.add(PasteboardContents(text: "word"), sourceApp: nil))
        store.setText("https://example.com", of: item.id)
        let edited = try #require(ItemStore(root: environment.root).item(item.id))
        #expect(edited.kind == .link)
        #expect(store.contents(of: edited).plainText == "https://example.com")
    }

    @Test func thePreviewFileOfATextItemIsATextFile() throws {
        let item = try #require(store.add(PasteboardContents(text: "word"), sourceApp: nil))
        let file = try #require(store.previewFile(of: item))
        #expect(file.pathExtension == "txt")
        #expect(try String(contentsOf: file, encoding: .utf8) == "word")
    }
}
