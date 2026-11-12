import AppKit
import Quartz

/// Shows an attachment in Quick Look - the same viewer as pressing Space in
/// Finder - so you can look at an image without leaving the app.
///
/// macOS hands the shared Quick Look panel to whoever in the responder chain
/// accepts it; AppDelegate does and passes it on to this object (see the
/// QLPreviewPanelController methods in AppDelegate).
final class AttachmentQuickLook: NSObject, QLPreviewPanelDataSource {
    static let shared = AttachmentQuickLook()

    private var urls: [URL] = []
    private var startIndex = 0

    /// Shows `urls`, starting at `index`; the arrow keys move between them.
    func show(_ urls: [URL], startingAt index: Int = 0) {
        guard urls.isEmpty == false else { return }
        self.urls = urls
        startIndex = min(max(index, 0), urls.count - 1)
        guard let panel = QLPreviewPanel.shared() else {
            NSWorkspace.shared.open(urls[startIndex])
            return
        }
        if panel.isVisible {
            panel.reloadData()
            panel.currentPreviewItemIndex = startIndex
        } else {
            panel.makeKeyAndOrderFront(nil)
        }
    }

    // MARK: Panel control (called from AppDelegate)

    func beginControl(of panel: QLPreviewPanel) {
        panel.dataSource = self
        panel.reloadData()
        panel.currentPreviewItemIndex = startIndex
    }

    func endControl(of panel: QLPreviewPanel) {
        panel.dataSource = nil
        urls = []
    }

    // MARK: QLPreviewPanelDataSource

    func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int {
        urls.count
    }

    func previewPanel(_ panel: QLPreviewPanel!, previewItemAt index: Int) -> QLPreviewItem! {
        urls.indices.contains(index) ? urls[index] as NSURL : nil
    }
}
