import AppKit
import Foundation

final class TaskStore: ObservableObject {
    @Published var tasks: [TaskItem] = [] {
        didSet {
            updateDerivedState()
            guard isLoading == false else { return }
            saveTasks()
        }
    }

    @Published var categories: [TaskCategory] = [] {
        didSet {
            guard isLoading == false else { return }
            saveCategories()
        }
    }

    @Published private(set) var taskCount: Int = 0
    @Published private(set) var completedTaskCount: Int = 0

    private let taskStorageKey = "StickyToDo.tasks"
    private let categoryStorageKey = "StickyToDo.categories"
    private let userDefaults: UserDefaults
    private let attachmentStore: AttachmentStore
    private var isLoading = false
    private var lastSavedTaskData: Data?
    private var lastSavedCategoryData: Data?

    init(userDefaults: UserDefaults = .standard, attachmentStore: AttachmentStore = AttachmentStore()) {
        self.userDefaults = userDefaults
        self.attachmentStore = attachmentStore
        load()
        updateDerivedState()
    }

    @discardableResult
    func addTask(title: String, categoryID: UUID? = nil, attachmentImage: NSImage? = nil) -> TaskItem? {
        guard let trimmed = normalizedTitle(from: title) else { return nil }
        var newTask = TaskItem(title: trimmed, categoryID: categoryID)
        if let attachmentImage, let id = attachmentStore.save(attachmentImage) {
            newTask.attachmentID = id
        }
        tasks.insert(newTask, at: 0)
        return newTask
    }

    func toggleDone(for task: TaskItem) {
        guard let index = indexOfTask(task) else { return }
        tasks[index].isDone.toggle()
        if tasks[index].isDone {
            tasks[index].doneAt = Date()
        } else {
            tasks[index].doneAt = nil
        }
    }

    func delete(_ task: TaskItem) {
        if let attachmentID = task.attachmentID {
            attachmentStore.delete(id: attachmentID)
        }
        tasks.removeAll { $0.id == task.id }
    }

    func updateTitle(for task: TaskItem, title: String) {
        guard let trimmed = normalizedTitle(from: title) else { return }
        guard let index = indexOfTask(task) else { return }
        tasks[index].title = trimmed
    }

    func setImportant(_ isImportant: Bool, for task: TaskItem) {
        guard let index = indexOfTask(task) else { return }
        tasks[index].isImportant = isImportant
    }

    func assignCategory(_ categoryID: UUID?, to task: TaskItem) {
        guard let index = indexOfTask(task) else { return }
        tasks[index].categoryID = categoryID
    }

    func assignCategory(_ categoryID: UUID?, toTaskID taskID: UUID) {
        guard let index = tasks.firstIndex(where: { $0.id == taskID }) else { return }
        tasks[index].categoryID = categoryID
    }

    func category(for id: UUID?) -> TaskCategory? {
        guard let id else { return nil }
        return categories.first { $0.id == id }
    }

    @discardableResult
    func createCategory(name: String) -> TaskCategory? {
        guard let trimmed = normalizedTitle(from: name) else { return nil }
        if let existing = categories.first(where: { $0.name.caseInsensitiveCompare(trimmed) == .orderedSame }) {
            return existing
        }
        let colorHex = Theme.categoryPalette[categories.count % Theme.categoryPalette.count]
        let category = TaskCategory(name: trimmed, colorHex: colorHex)
        categories.append(category)
        return category
    }

    func renameCategory(id: UUID, to name: String) {
        guard let trimmed = normalizedTitle(from: name) else { return }
        guard let index = categories.firstIndex(where: { $0.id == id }) else { return }
        let duplicateExists = categories.contains {
            $0.id != id && $0.name.caseInsensitiveCompare(trimmed) == .orderedSame
        }
        guard duplicateExists == false else { return }
        categories[index].name = trimmed
    }

    func deleteCategory(id: UUID) {
        categories.removeAll { $0.id == id }
        for index in tasks.indices where tasks[index].categoryID == id {
            tasks[index].categoryID = nil
        }
    }

    func moveTask(from sourceId: UUID, to targetId: UUID) {
        guard sourceId != targetId else { return }
        guard let sourceIndex = tasks.firstIndex(where: { $0.id == sourceId }) else { return }
        guard let targetIndex = tasks.firstIndex(where: { $0.id == targetId }) else { return }
        let item = tasks.remove(at: sourceIndex)
        let adjustedIndex = targetIndex > sourceIndex ? targetIndex - 1 : targetIndex
        tasks.insert(item, at: adjustedIndex)
    }

    func setAttachment(_ image: NSImage, for task: TaskItem) {
        guard let index = indexOfTask(task) else { return }
        if let oldID = tasks[index].attachmentID {
            attachmentStore.delete(id: oldID)
        }
        guard let newID = attachmentStore.save(image) else { return }
        tasks[index].attachmentID = newID
    }

    func removeAttachment(for task: TaskItem) {
        guard let index = indexOfTask(task) else { return }
        if let id = tasks[index].attachmentID {
            attachmentStore.delete(id: id)
        }
        tasks[index].attachmentID = nil
    }

    func attachmentImage(for task: TaskItem) -> NSImage? {
        guard let id = task.attachmentID else { return nil }
        return attachmentStore.loadImage(for: id)
    }

    func openAttachment(for task: TaskItem) {
        guard let id = task.attachmentID else { return }
        NSWorkspace.shared.open(attachmentStore.url(for: id))
    }

    /// Removes completed tasks left over from a previous day, keeping today's
    /// completed tasks visible. Returns the number of tasks removed.
    @discardableResult
    func purgeStaleCompletedTasks(referenceDate: Date = Date(), calendar: Calendar = .current) -> Int {
        let staleIDs = tasks
            .filter { task in
                guard task.isDone else { return false }
                guard let doneAt = task.doneAt else { return true }
                return calendar.isDate(doneAt, inSameDayAs: referenceDate) == false
            }
            .map(\.id)
        guard staleIDs.isEmpty == false else { return 0 }
        let staleIDSet = Set(staleIDs)
        tasks.removeAll { staleIDSet.contains($0.id) }
        return staleIDs.count
    }

    private func load() {
        isLoading = true
        defer { isLoading = false }

        if let data = userDefaults.data(forKey: taskStorageKey) {
            do {
                tasks = try JSONDecoder().decode([TaskItem].self, from: data)
            } catch {
                tasks = []
            }
        } else {
            tasks = []
        }

        if let data = userDefaults.data(forKey: categoryStorageKey) {
            do {
                categories = try JSONDecoder().decode([TaskCategory].self, from: data)
            } catch {
                categories = []
            }
        } else {
            categories = []
        }

        // Ensure old references to removed categories are cleaned up.
        let existingCategoryIDs = Set(categories.map(\.id))
        for index in tasks.indices where tasks[index].categoryID != nil {
            guard let categoryID = tasks[index].categoryID else { continue }
            if existingCategoryIDs.contains(categoryID) == false {
                tasks[index].categoryID = nil
            }
        }

        if purgeStaleCompletedTasks() > 0 {
            saveTasks()
        }

        lastSavedTaskData = try? JSONEncoder().encode(tasks)
        lastSavedCategoryData = try? JSONEncoder().encode(categories)
    }

    private func saveTasks() {
        do {
            let data = try JSONEncoder().encode(tasks)
            guard data != lastSavedTaskData else { return }
            userDefaults.set(data, forKey: taskStorageKey)
            lastSavedTaskData = data
        } catch {
            // Keep running without crashing.
        }
    }

    private func saveCategories() {
        do {
            let data = try JSONEncoder().encode(categories)
            guard data != lastSavedCategoryData else { return }
            userDefaults.set(data, forKey: categoryStorageKey)
            lastSavedCategoryData = data
        } catch {
            // Keep running without crashing.
        }
    }

    private func updateDerivedState() {
        var total = 0
        var completed = 0
        for task in tasks {
            total += 1
            if task.isDone {
                completed += 1
            }
        }
        if taskCount != total {
            taskCount = total
        }
        if completedTaskCount != completed {
            completedTaskCount = completed
        }
    }

    private func normalizedTitle(from raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func indexOfTask(_ task: TaskItem) -> Int? {
        tasks.firstIndex { $0.id == task.id }
    }
}
