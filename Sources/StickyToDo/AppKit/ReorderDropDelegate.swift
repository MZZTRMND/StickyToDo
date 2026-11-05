import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct ReorderDropDelegate: DropDelegate {
    let target: TaskItem
    let store: TaskStore
    @Binding var draggingId: UUID?
    /// The row an outside image is being dragged over, for its highlight.
    @Binding var imageDropTargetID: UUID?
    /// The task whose own thumbnail is being dragged, if any. A binding, so
    /// it's read live: rows don't rebuild when it changes.
    @Binding var draggedAttachmentTaskID: UUID?

    func validateDrop(info: DropInfo) -> Bool {
        if isImageDrop(info) {
            return draggedAttachmentTaskID != target.id
        }
        return info.hasItemsConforming(to: [UTType.text])
    }

    /// An image from outside the list - not a task being reordered.
    private func isImageDrop(_ info: DropInfo) -> Bool {
        draggingId == nil && info.hasItemsConforming(to: [UTType.image])
    }

    func dropExited(info: DropInfo) {
        if imageDropTargetID == target.id {
            imageDropTargetID = nil
        }
    }

    func dropEntered(info: DropInfo) {
        if isImageDrop(info), draggedAttachmentTaskID != target.id {
            imageDropTargetID = target.id
            return
        }
        guard let draggingId, draggingId != target.id else { return }
        withAnimation(.easeInOut(duration: 0.12)) {
            store.moveTask(from: draggingId, to: target.id)
        }
    }

    func performDrop(info: DropInfo) -> Bool {
        imageDropTargetID = nil
        if isImageDrop(info) {
            // Its own image dropped back on it: nothing to do.
            guard draggedAttachmentTaskID != target.id else { return false }
        }
        if draggingId == nil, info.hasItemsConforming(to: [UTType.image]),
           let provider = info.itemProviders(for: [UTType.image]).first {
            ImageItemProviderLoader.loadImage(from: provider) { image in
                guard let image else { return }
                DispatchQueue.main.async {
                    store.setAttachment(image, for: target)
                }
            }
            return true
        }
        draggingId = nil
        return true
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        if isImageDrop(info) {
            return DropProposal(operation: draggedAttachmentTaskID == target.id ? .forbidden : .copy)
        }
        return DropProposal(operation: .move)
    }
}
