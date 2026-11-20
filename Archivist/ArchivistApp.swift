import AppKit
import ServiceManagement

@main
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private static let shared = AppDelegate()

    static func main() {
        NSApplication.shared.delegate = shared
        NSApplication.shared.run()
    }

    private var statusItemController: StatusItemController?
    private var historyPanel: HistoryPanel?
    private var retentionTimer: Timer?
    private var updateRelauncher: UpdateRelauncher?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // The unit tests run inside the app: do not add a login item, a menu bar icon or a hot key,
        // and do not read the history of the user.
        guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil else { return }
        Settings.registerDefaults()
        LoginItem.enableOnFirstLaunch()

        let store = ItemStore()
        let pinboards = PinboardStore()
        let monitor = ClipboardMonitor(store: store)
        let model = HistoryModel(store: store, pinboards: pinboards, monitor: monitor)
        let historyPanel = HistoryPanel(model: model)
        let settingsWindow = SettingsWindow(model: model)
        model.showSettings = { settingsWindow.show() }
        self.historyPanel = historyPanel
        statusItemController = StatusItemController(model: model, historyPanel: historyPanel)

        model.deleteOldItems()
        retentionTimer = Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { _ in
            MainActor.assumeIsolated { model.deleteOldItems() }
        }
        monitor.start()
        HotKey.register { historyPanel.toggle() }

        let updateRelauncher = UpdateRelauncher(isBusy: { historyPanel.isVisible })
        updateRelauncher.start()
        self.updateRelauncher = updateRelauncher
    }
}

enum LoginItem {
    static var isEnabled: Bool { SMAppService.mainApp.status == .enabled }

    static func set(_ isEnabled: Bool) {
        try? isEnabled ? SMAppService.mainApp.register() : SMAppService.mainApp.unregister()
    }

    static func enableOnFirstLaunch() {
        let key = "didEnableLoginItem"
        guard !UserDefaults.standard.bool(forKey: key) else { return }
        UserDefaults.standard.set(true, forKey: key)
        set(true)
    }
}
