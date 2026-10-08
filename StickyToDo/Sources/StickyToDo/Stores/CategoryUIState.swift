import SwiftUI

/// Ephemeral UI state for the category strip and creation/rename modal.
/// Persisted category data itself stays owned by `TaskStore`; this object
/// only orchestrates what the category UI is currently doing.
final class CategoryUIState: ObservableObject {
    @Published var selectedCategoryID: UUID?
    @Published var editingCategoryID: UUID?
    @Published var categoryNameDraft = ""
    @Published var isCategoryCreationPresented = false
    @Published var pendingCategoryTaskID: UUID?
    @Published var newCategoryName = ""
    @Published var isCategoryModalAnimatingIn = false
    @Published var categoryShakeTrigger: CGFloat = 0
    @Published var isAllCategoryDropTargeted = false
    @Published var categoryDropTargetedIDs: Set<UUID> = []
    @Published var isCategorySectionHovered = false

    func clearSelectionIfMissing(from categories: [TaskCategory]) {
        if let selectedCategoryID, categories.contains(where: { $0.id == selectedCategoryID }) == false {
            self.selectedCategoryID = nil
        }
    }

    /// The category a newly added task should land in: whichever tab is
    /// showing, so the task appears where you're looking instead of going
    /// uncategorized and vanishing from a filtered tab. nil on "All", or if
    /// the selected category no longer exists.
    func categoryIDForNewTask(in store: TaskStore) -> UUID? {
        store.category(for: selectedCategoryID)?.id
    }

    /// Called after a task is added to `categoryID`: if the tab showing
    /// wouldn't include it, switch to the tab that does, so you see it land.
    /// "All" shows everything, so it never switches away from there.
    func revealNewTask(inCategory categoryID: UUID?) {
        guard selectedCategoryID != nil, selectedCategoryID != categoryID else { return }
        selectedCategoryID = categoryID
    }

    func beginCategoryCreation(for taskID: UUID?) {
        cancelCategoryRename()
        pendingCategoryTaskID = taskID
        newCategoryName = ""
        isCategoryCreationPresented = true
    }

    func confirmCategoryCreation(store: TaskStore) {
        let trimmed = newCategoryName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else {
            withAnimation(.spring(response: 0.22, dampingFraction: 0.55)) {
                categoryShakeTrigger += 1
            }
            return
        }
        guard let category = store.createCategory(name: newCategoryName) else { return }
        if let taskID = pendingCategoryTaskID {
            store.assignCategory(category.id, toTaskID: taskID)
        } else {
            selectedCategoryID = category.id
        }
        cancelCategoryCreation()
    }

    func cancelCategoryCreation() {
        newCategoryName = ""
        pendingCategoryTaskID = nil
        isCategoryCreationPresented = false
    }

    func beginCategoryRename(_ category: TaskCategory) {
        cancelCategoryRename()
        editingCategoryID = category.id
        categoryNameDraft = category.name
    }

    func commitCategoryRename(categoryID: UUID, store: TaskStore) {
        store.renameCategory(id: categoryID, to: categoryNameDraft)
        cancelCategoryRename()
    }

    func cancelCategoryRename() {
        categoryNameDraft = ""
        editingCategoryID = nil
    }

    func deleteCategory(id: UUID, store: TaskStore) {
        if selectedCategoryID == id {
            selectedCategoryID = nil
        }
        if editingCategoryID == id {
            cancelCategoryRename()
        }
        store.deleteCategory(id: id)
    }

    func dropTargetBinding(for id: UUID) -> Binding<Bool> {
        Binding(
            get: { self.categoryDropTargetedIDs.contains(id) },
            set: { isTargeted in
                if isTargeted {
                    self.categoryDropTargetedIDs.insert(id)
                } else {
                    self.categoryDropTargetedIDs.remove(id)
                }
            }
        )
    }
}
