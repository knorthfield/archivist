import Carbon.HIToolbox
import Testing
@testable import Archivist

@MainActor
struct PasterTests {
    @Test func theVKeyOfTheUSLayoutIsTheQwertyVKey() throws {
        let filter = [kTISPropertyInputSourceID as String: "com.apple.keylayout.US"] as CFDictionary
        let layouts = TISCreateInputSourceList(filter, true).takeRetainedValue() as? [TISInputSource]
        let layout = try #require(layouts?.first)
        #expect(Paster.commandVKey(in: layout) == Paster.qwertyV)
    }
}
