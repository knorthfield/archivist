import Foundation
import Testing
@testable import Archivist

@MainActor
struct PinboardStoreTests {
    let environment = TestEnvironment()
    var pinboards: PinboardStore { environment.pinboards }

    @Test func pinboardsStayAfterARestart() {
        let item = UUID()
        let work = pinboards.add(name: "Work", colour: .green)
        pinboards.pin([item], to: work.id)
        let reopened = PinboardStore(root: environment.root)
        #expect(reopened.pinboards.map(\.name) == ["Work"])
        #expect(reopened.pinboards.first?.colour == .green)
        #expect(reopened.pinboards.first?.itemIDs == [item])
    }

    @Test func anItemIsInOnePinboardAtATime() {
        let item = UUID()
        let work = pinboards.add(name: "Work", colour: .green)
        let home = pinboards.add(name: "Home", colour: .red)
        pinboards.pin([item], to: work.id)
        pinboards.pin([item], to: home.id)
        #expect(pinboards.pinboard(work.id)?.itemIDs == [])
        #expect(pinboards.pinboard(home.id)?.itemIDs == [item])
        #expect(pinboards.pinnedIDs == [item])
    }

    @Test func aSecondPinToTheSamePinboardDoesNothing() {
        let (first, second) = (UUID(), UUID())
        let work = pinboards.add(name: "Work", colour: .green)
        pinboards.pin([first, second], to: work.id)
        pinboards.pin([first], to: work.id)
        #expect(pinboards.pinboard(work.id)?.itemIDs == [first, second])
    }

    @Test func itemsAndPinboardsCanMove() {
        let (first, second, third) = (UUID(), UUID(), UUID())
        let work = pinboards.add(name: "Work", colour: .green)
        let home = pinboards.add(name: "Home", colour: .red)
        pinboards.pin([first, second, third], to: work.id)
        pinboards.moveItem(third, toPositionOf: first)
        #expect(pinboards.pinboard(work.id)?.itemIDs == [third, first, second])
        pinboards.move(home.id, toPositionOf: work.id)
        #expect(pinboards.pinboards.map(\.name) == ["Home", "Work"])
    }

    @Test func unpinRemovesTheItem() {
        let item = UUID()
        let work = pinboards.add(name: "Work", colour: .green)
        pinboards.pin([item], to: work.id)
        pinboards.unpin([item])
        #expect(pinboards.pinnedIDs.isEmpty)
    }
}
