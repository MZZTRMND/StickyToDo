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

    /// Its own image dropped back on it, or no room for another.
    private var refusesImages: Bool {
        draggedAttachmentTaskID == target.id || currentTarget?.canAddAttachment == false
    }

    /// `target` as the store has it now - the row (and with it this
    /// delegate) isn't rebuilt on every change.
    private var currentTarget: TaskItem? {
        store.tasks.first { $0.id == target.id }
    }

    func validateDrop(info: DropInfo) -> Bool {
        if isImageDrop(info) {
            return refusesImages == false
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
        if isImageDrop(info), refusesImages == false {
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
            guard refusesImages == false else { return false }
        }
        if draggingId == nil, info.hasItemsConforming(to: [UTType.image]) {
            // Several dropped at once are all added, as far as there's room
            // (the store ignores any beyond the maximum).
            let room = currentTarget.map { TaskItem.maxAttachments - $0.attachmentIDs.count } ?? 0
            let providers = info.itemProviders(for: [UTType.image]).prefix(max(room, 0))
            guard providers.isEmpty == false else { return false }
            let taskID = target.id
            for provider in providers {
                ImageItemProviderLoader.loadImage(from: provider) { image in
                    guard let image else { return }
                    DispatchQueue.main.async {
                        guard let task = store.tasks.first(where: { $0.id == taskID }) else { return }
                        store.addAttachment(image, to: task)
                    }
                }
            }
            return true
        }
        draggingId = nil
        return true
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        if isImageDrop(info) {
            return DropProposal(operation: refusesImages ? .forbidden : .copy)
        }
        return DropProposal(operation: .move)
    }
}
