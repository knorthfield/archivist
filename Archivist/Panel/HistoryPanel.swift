import AppKit
import Carbon.HIToolbox
import SwiftUI

/// The window with the history, across the bottom of the screen. It does not make Archivist the
/// active app, so that a paste goes to the app that the user works in.
@MainActor
final class HistoryPanel: NSObject, NSWindowDelegate {
    private static let height: CGFloat = 330

    private let panel: KeyPanel
    private let model: HistoryModel
    private let quickLook = QuickLook()

    init(model: HistoryModel) {
        self.model = model
        panel = KeyPanel(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: Self.height),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        super.init()
        panel.isFloatingPanel = true
        // Above the Dock.
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.animationBehavior = .none
        panel.delegate = self

        let host = NSHostingController(rootView: HistoryView(model: model))
        // Never `.preferredContentSize`: on macOS 26 it can recurse and crash.
        host.sizingOptions = []
        panel.contentViewController = host

        panel.keyDownHandler = { [weak self] event in self?.handleKeyDown(event) ?? false }
        model.hidePanel = { [weak self] in self?.hide() }
        model.showQuickLook = { [weak self] urls in self?.quickLook.show(urls) }
    }

    func toggle() {
        if panel.isVisible { hide() } else { show() }
    }

    func show() {
        let mouse = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { NSMouseInRect(mouse, $0.frame, false) }) ?? NSScreen.main
        else { return }
        model.prepareToShow()
        let shown = NSRect(x: screen.frame.minX, y: screen.frame.minY, width: screen.frame.width, height: Self.height)
        panel.setFrame(shown.offsetBy(dx: 0, dy: -Self.height), display: false)
        panel.makeKeyAndOrderFront(nil)
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.18
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().setFrame(shown, display: true)
        }
    }

    func hide() {
        guard panel.isVisible else { return }
        quickLook.close()
        panel.orderOut(nil)
    }

    /// A click in a different window closes the panel.
    func windowDidResignKey(_ notification: Notification) {
        guard !quickLook.isOpen else { return }
        hide()
    }

    private func handleKeyDown(_ event: NSEvent) -> Bool {
        guard quickLook.isOpen else { return model.handleKeyDown(event) }
        let keyCode = Int(event.keyCode)
        if keyCode == kVK_Escape || keyCode == kVK_Space {
            quickLook.close()
            return true
        }
        let wasHandled = model.handleKeyDown(event)
        // The arrow keys change the selection: show the new selection.
        if panel.isVisible { quickLook.show(model.selectedItems.compactMap(model.store.previewFile)) }
        return wasHandled
    }
}

/// A panel without a title bar cannot get the keyboard, unless it says that it can.
private final class KeyPanel: NSPanel {
    var keyDownHandler: ((NSEvent) -> Bool)?

    override var canBecomeKey: Bool { true }

    override func sendEvent(_ event: NSEvent) {
        if event.type == .keyDown, keyDownHandler?(event) == true { return }
        super.sendEvent(event)
    }
}
