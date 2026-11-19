import AppKit
import Quartz

/// Shows the Quick Look window for the selected items.
@MainActor
final class QuickLook: NSObject, @preconcurrency QLPreviewPanelDataSource {
    private(set) var isOpen = false
    private var urls: [URL] = []

    func show(_ urls: [URL]) {
        guard !urls.isEmpty, let panel = QLPreviewPanel.shared() else { return }
        self.urls = urls
        panel.dataSource = self
        panel.reloadData()
        guard !isOpen else { return }
        isOpen = true
        // Above the history panel.
        panel.level = .popUpMenu
        panel.orderFront(nil)
    }

    func close() {
        guard isOpen else { return }
        isOpen = false
        QLPreviewPanel.shared()?.orderOut(nil)
    }

    func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int {
        urls.count
    }

    func previewPanel(_ panel: QLPreviewPanel!, previewItemAt index: Int) -> QLPreviewItem! {
        urls[index] as NSURL
    }
}
