import AppKit
import SwiftUI

/// Where a row gets its attachment's thumbnail from, and how it's dragged
/// out. ContentView fills it in from the TaskStore.
struct AttachmentPreviewSource {
    /// Already-loaded thumbnail, if any - shown at once, so rows rebuilt on
    /// a tab switch don't flash an empty placeholder.
    var cached: (UUID) -> NSImage?
    /// Loads it from disk; `completion` runs on the main thread.
    var load: (UUID, @escaping (NSImage?) -> Void) -> Void
    /// What dragging the thumbnail out of the card carries.
    var dragItem: (UUID) -> NSItemProvider?
    /// Called when a drag of this thumbnail starts, so dropping it back on
    /// its own task does nothing.
    var onDragStarted: () -> Void
}

/// The task's image, shown small under its title so the reminder is visible
/// at a glance. Click opens Quick Look; drag it out into Figma, Slack,
/// Mail or Finder.
struct AttachmentThumbnail: View {
    let attachmentID: UUID
    let isDone: Bool
    /// A square tile, for a row of several images.
    var isTile = false
    let source: AttachmentPreviewSource
    let onOpen: () -> Void

    @State private var loaded: (id: UUID, image: NSImage?)?
    @State private var isHovered = false

    static let height: CGFloat = 48
    private static let widthRange: ClosedRange<CGFloat> = 40...160
    private static let placeholderWidth: CGFloat = 64

    var body: some View {
        let image = currentImage
        content(image)
            .frame(width: width(for: image), height: Self.height)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(Theme.separator.opacity(isHovered ? 1 : 0.6), lineWidth: 0.5)
            )
            .opacity(isDone ? 0.5 : 1)
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .onTapGesture(perform: onOpen)
            .onHover { isHovered = $0 }
            .pointingHandCursorOnHover()
            .onDrag {
                source.onDragStarted()
                return source.dragItem(attachmentID) ?? NSItemProvider()
            }
            .help("Click to preview, drag to copy it elsewhere")
            .accessibilityElement()
            .accessibilityLabel("Image attachment")
            .accessibilityAddTraits([.isButton, .isImage])
            .accessibilityAction { onOpen() }
            .onAppear(perform: loadIfNeeded)
            .onChange(of: attachmentID) { loadIfNeeded() }
            .animation(.easeInOut(duration: 0.15), value: image == nil)
    }

    @ViewBuilder
    private func content(_ image: NSImage?) -> some View {
        if let image {
            Image(nsImage: image)
                .resizable()
                .interpolation(.high)
                .aspectRatio(contentMode: .fill)
        } else {
            Rectangle()
                .fill(Theme.hoverFill)
                .overlay {
                    Image(systemName: "photo")
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.tertiaryText)
                }
        }
    }

    private var currentImage: NSImage? {
        if let loaded, loaded.id == attachmentID {
            return loaded.image
        }
        return source.cached(attachmentID)
    }

    /// Keeps the image's shape, within limits: a tall phone screenshot
    /// doesn't become a sliver, a wide one doesn't run across the card.
    private func width(for image: NSImage?) -> CGFloat {
        if isTile { return Self.height }
        guard let image, image.size.height > 0 else { return Self.placeholderWidth }
        let natural = Self.height * image.size.width / image.size.height
        return min(max(natural, Self.widthRange.lowerBound), Self.widthRange.upperBound)
    }

    private func loadIfNeeded() {
        let id = attachmentID
        guard currentImage == nil else { return }
        source.load(id) { image in
            loaded = (id, image)
        }
    }
}
