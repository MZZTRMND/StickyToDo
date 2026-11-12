import SwiftUI
import UniformTypeIdentifiers

struct CategoryChipDropDelegate: DropDelegate {
    let categoryID: UUID?
    let store: TaskStore
    @Binding var draggingId: UUID?
    @Binding var isTargeted: Bool

    func validateDrop(info: DropInfo) -> Bool {
        info.hasItemsConforming(to: [UTType.text])
    }

    func dropEntered(info: DropInfo) {
        isTargeted = true
    }

    func dropExited(info: DropInfo) {
        isTargeted = false
    }

    func performDrop(info: DropInfo) -> Bool {
        if let draggingId {
            store.assignCategory(categoryID, toTaskID: draggingId)
        }
        self.draggingId = nil
        isTargeted = false
        return true
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }
}
