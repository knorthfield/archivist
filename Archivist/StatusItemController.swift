import AppKit
import Observation

/// The menu bar icon and its menu.
@MainActor
final class StatusItemController: NSObject, NSMenuDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let menu = NSMenu()
    private let model: HistoryModel
    private let historyPanel: HistoryPanel

    init(model: HistoryModel, historyPanel: HistoryPanel) {
        self.model = model
        self.historyPanel = historyPanel
        super.init()
        menu.delegate = self
        statusItem.menu = menu
        showPauseState()
    }

    private func showPauseState() {
        withObservationTracking {
            let isPaused = model.monitor.isPaused
            statusItem.button?.image = NSImage(
                systemSymbolName: "clipboard",
                accessibilityDescription: isPaused ? "Archivist, paused" : "Archivist")
            statusItem.button?.appearsDisabled = isPaused
        } onChange: { [weak self] in
            Task { @MainActor in self?.showPauseState() }
        }
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        let showItem = menu.addItem(withTitle: "Show Archivist", action: #selector(showHistory), keyEquivalent: "v")
        showItem.keyEquivalentModifierMask = [.command, .shift]
        showItem.target = self
        menu.addItem(.separator())

        if model.monitor.isPaused {
            menu.addItem(withTitle: "Archivist is paused", action: nil, keyEquivalent: "")
            menu.addItem(withTitle: "Resume", action: #selector(resume), keyEquivalent: "").target = self
        } else {
            let pauseItem = menu.addItem(withTitle: "Pause", action: nil, keyEquivalent: "")
            pauseItem.image = NSImage(systemSymbolName: "pause", accessibilityDescription: nil)
            let pauseMenu = NSMenu()
            for (title, seconds) in [("For 15 Minutes", 900), ("For 1 Hour", 3600), ("Until I Resume", 0)] {
                let item = pauseMenu.addItem(withTitle: title, action: #selector(pause), keyEquivalent: "")
                item.target = self
                item.tag = seconds
            }
            pauseItem.submenu = pauseMenu
        }

        menu.addItem(.separator())
        let settingsItem = menu.addItem(withTitle: "Settings…", action: #selector(showSettings), keyEquivalent: ",")
        settingsItem.target = self
        settingsItem.image = NSImage(systemSymbolName: "gear", accessibilityDescription: nil)
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Archivist", action: #selector(NSApplication.terminate), keyEquivalent: "q")
    }

    @objc private func showHistory() {
        historyPanel.show()
    }

    @objc private func pause(_ item: NSMenuItem) {
        model.monitor.pause(until: item.tag == 0 ? .distantFuture : Date(timeIntervalSinceNow: TimeInterval(item.tag)))
    }

    @objc private func resume() {
        model.monitor.resume()
    }

    @objc private func showSettings() {
        model.showSettings()
    }
}
