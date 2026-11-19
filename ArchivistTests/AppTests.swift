import Foundation
import Testing
@testable import Archivist

struct AppTests {
    @Test func theAppIsAMenuBarApp() {
        #expect(Bundle.main.object(forInfoDictionaryKey: "LSUIElement") as? Bool == true)
    }
}
