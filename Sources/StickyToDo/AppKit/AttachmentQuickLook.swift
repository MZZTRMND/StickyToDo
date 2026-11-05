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

    private var url: URL?

    func show(_ url: URL) {
        self.url = url
        guard let panel = QLPreviewPanel.shared() else {
            NSWorkspace.shared.open(url)
            return
        }
        if panel.isVisible {
            panel.reloadData()
        } else {
            panel.makeKeyAndOrderFront(nil)
        }
    }

    // MARK: Panel control (called from AppDelegate)

    func beginControl(of panel: QLPreviewPanel) {
        panel.dataSource = self
        panel.reloadData()
    }

    func endControl(of panel: QLPreviewPanel) {
        panel.dataSource = nil
        url = nil
    }

    // MARK: QLPreviewPanelDataSource

    func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int {
        url == nil ? 0 : 1
    }

    func previewPanel(_ panel: QLPreviewPanel!, previewItemAt index: Int) -> QLPreviewItem! {
        url as NSURL?
    }
}
