import AppKit
import Testing
@testable import Archivist

@MainActor
struct HistoryModelTests {
    let environment = TestEnvironment()
    var model: HistoryModel { environment.model }
    var store: ItemStore { environment.store }

    @discardableResult
    private func add(_ text: String, at seconds: TimeInterval = Date.now.timeIntervalSince1970) -> ClipboardItem {
        store.add(PasteboardContents(text: text), sourceApp: safari, date: Date(timeIntervalSince1970: seconds))!
    }

    @Test func aSearchLooksInAllItemsAndSelectsTheFirstResult() {
        let apple = add("apple", at: 1)
        add("banana", at: 2)
        let work = environment.pinboards.add(name: "Work", colour: .blue)
        model.selectedPinboardID = work.id
        #expect(model.visibleItems.isEmpty)
        model.query = "app"
        #expect(model.visibleItems == [apple])
        #expect(model.selection == [apple.id])
    }

    @Test func aPinboardShowsItsItemsInTheirSequence() {
        let first = add("first", at: 1)
        let second = add("second", at: 2)
        let work = environment.pinboards.add(name: "Work", colour: .blue)
        environment.pinboards.pin([first.id, second.id], to: work.id)
        model.selectedPinboardID = work.id
        #expect(model.visibleItems.map(\.text) == ["first", "second"])
    }

    @Test func theArrowKeysMoveAndExtendTheSelection() {
        let c = add("c", at: 1), b = add("b", at: 2), a = add("a", at: 3)
        model.prepareToShow()
        #expect(model.selection == [a.id])
        model.moveCursor(by: 1)
        #expect(model.selection == [b.id])
        model.moveCursor(by: 1, extending: true)
        #expect(model.selection == [b.id, c.id])
        model.moveCursor(by: 1)
        #expect(model.selection == [c.id])
        model.moveCursor(by: -10)
        #expect(model.selection == [a.id])
    }

    @Test func aCommandClickAddsAndRemovesOneItem() {
        let b = add("b", at: 1), a = add("a", at: 2)
        model.select(a.id)
        model.select(b.id, mode: .toggle)
        #expect(model.selection == [a.id, b.id])
        model.select(a.id, mode: .toggle)
        #expect(model.selection == [b.id])
    }

    @Test func oneItemIsPastedWithAllItsTypes() {
        let contents = PasteboardContents(items: [[
            .init(type: "public.utf8-plain-text", data: Data("Hello".utf8)),
            .init(type: "public.rtf", data: Data("{\\rtf1 Hello}".utf8)),
        ]])
        let item = store.add(contents, sourceApp: safari)!
        #expect(model.contents(toPaste: [item], asPlainText: false) == contents)
        #expect(model.contents(toPaste: [item], asPlainText: true) == PasteboardContents(text: "Hello"))
    }

    @Test func someTextItemsArePastedAsOneText() {
        let b = add("b", at: 1), a = add("a", at: 2)
        #expect(model.contents(toPaste: [a, b], asPlainText: false) == PasteboardContents(text: "a\nb"))
    }

    @Test func aCopyFromThePanelGoesOnTheClipboardAndIsNotANewItem() {
        _ = environment.monitor
        let a = add("a")
        add("b")
        model.copy([a])
        #expect(environment.pasteboard.string(forType: .string) == "a")
        environment.monitor.check(sourceApp: safari)
        #expect(store.items.map(\.text) == ["b", "a"])
    }

    @Test func deleteSelectsTheNextItemAndUndoPutsThePinBack() {
        let c = add("c", at: 1), b = add("b", at: 2), a = add("a", at: 3)
        let work = environment.pinboards.add(name: "Work", colour: .blue)
        environment.pinboards.pin([b.id], to: work.id)
        model.delete([b])
        #expect(model.visibleItems == [a, c])
        #expect(model.selection == [c.id])
        #expect(environment.pinboards.pinnedIDs.isEmpty)
        model.undoDelete()
        #expect(model.visibleItems == [a, b, c])
        #expect(environment.pinboards.pinboard(work.id)?.itemIDs == [b.id])
    }

    @Test func oldItemsGoWhenTheyArePastTheKeepHistorySetting() {
        let now = Date(timeIntervalSince1970: 10_000_000)
        environment.defaults.set(HistoryRetention.week.rawValue, forKey: Settings.keepHistory)
        add("old", at: now.timeIntervalSince1970 - 8 * 86400)
        add("new", at: now.timeIntervalSince1970 - 6 * 86400)
        model.deleteOldItems(now: now)
        #expect(store.items.map(\.text) == ["new"])

        environment.defaults.set(HistoryRetention.forever.rawValue, forKey: Settings.keepHistory)
        add("very old", at: 1)
        model.deleteOldItems(now: now)
        #expect(store.items.count == 2)
    }

    @Test func aDeletedPinboardTakesItsItemsWithIt() {
        let b = add("b", at: 1)
        add("a", at: 2)
        let work = environment.pinboards.add(name: "Work", colour: .blue)
        environment.pinboards.pin([b.id], to: work.id)
        model.selectedPinboardID = work.id
        model.deletePinboard(work)
        #expect(environment.pinboards.pinboards.isEmpty)
        #expect(model.selectedPinboardID == nil)
        #expect(store.items.map(\.text) == ["a"])
    }

    @Test func aNewItemInAPinboardIsPinnedThere() {
        let work = environment.pinboards.add(name: "Work", colour: .blue)
        model.selectedPinboardID = work.id
        model.addItem(text: "note")
        #expect(model.visibleItems.map(\.text) == ["note"])
    }

    @Test func aDropOnAPinboardPinsTheDraggedSelection() {
        let b = add("b", at: 1), a = add("a", at: 2)
        let work = environment.pinboards.add(name: "Work", colour: .blue)
        model.select(a.id)
        model.select(b.id, mode: .range)
        model.startDrag(of: a)
        #expect(model.dropOnPinboard(work))
        #expect(environment.pinboards.pinboard(work.id)?.itemIDs == [a.id, b.id])
        #expect(!model.dropOnPinboard(work))
    }
}
