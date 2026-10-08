import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct ReorderDropDelegate: DropDelegate {
    let target: TaskItem
    let store: TaskStore
    @Binding var draggingId: UUID?

    func validateDrop(info: DropInfo) -> Bool {
        info.hasItemsConforming(to: [UTType.text, UTType.image])
    }

    func dropEntered(info: DropInfo) {
        guard let draggingId, draggingId != target.id else { return }
        withAnimation(.easeInOut(duration: 0.12)) {
            store.moveTask(from: draggingId, to: target.id)
        }
    }

    func performDrop(info: DropInfo) -> Bool {
        if info.hasItemsConforming(to: [UTType.image]),
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
        if info.hasItemsConforming(to: [UTType.image]) {
            return DropProposal(operation: .copy)
        }
        return DropProposal(operation: .move)
    }
}
