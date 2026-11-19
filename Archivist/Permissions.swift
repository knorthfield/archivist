import AppKit

/// The app needs Accessibility to press ⌘V in the app at the front.
enum Permissions {
    static var hasAccessibility: Bool {
        AXIsProcessTrusted()
    }

    /// Adds the app to the Accessibility list and shows the system prompt.
    static func requestAccessibility() {
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }
}
