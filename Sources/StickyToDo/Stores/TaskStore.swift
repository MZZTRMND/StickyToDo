import AppKit
import Foundation
import UniformTypeIdentifiers

final class TaskStore: ObservableObject {
    @Published var tasks: [TaskItem] = [] {
        didSet {
            updateDerivedState()
            guard isLoading == false else { return }
            save()
        }
    }

    @Published var categories: [TaskCategory] = [] {
        didSet {
            guard isLoading == false else { return }
            save()
        }
    }

    @Published private(set) var taskCount: Int = 0
    @Published private(set) var completedTaskCount: Int = 0

    private let persistence: LibraryPersistence
    private let attachmentStore: AttachmentStore
    private var isLoading = false
    /// The list as last loaded or saved, with its change history: what the
    /// next save is compared against to see what changed.
    private var saved = LibrarySnapshot.empty

    init(
        persistence: LibraryPersistence = UserDefaultsPersistence(),
        attachmentStore: AttachmentStore = AttachmentStore(savesInBackground: true)
    ) {
        self.persistence = persistence
        self.attachmentStore = attachmentStore
        load()
        updateDerivedState()
    }

    @discardableResult
    func addTask(title: String, categoryID: UUID? = nil, attachmentImage: NSImage? = nil) -> TaskItem? {
        guard let trimmed = normalizedTitle(from: title) else { return nil }
        var newTask = TaskItem(title: trimmed, categoryID: categoryID)
        // The task appears right away; its image is attached once saved
        // (immediately when the attachment store saves synchronously).
        var isInserted = false
        if let attachmentImage {
            let taskID = newTask.id
            attachmentStore.save(attachmentImage) { [weak self] id in
                if isInserted {
                    self?.attachSavedImage(id, toTaskID: taskID)
                } else if let id {
                    newTask.attachmentIDs.append(id)
                }
            }
        }
        tasks.insert(newTask, at: 0)
        isInserted = true
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
        let attachmentIDs = tasks.first { $0.id == task.id }?.attachmentIDs ?? task.attachmentIDs
        for attachmentID in attachmentIDs {
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

    /// Adds an image to the task, unless it already has the maximum. Saves
    /// in the background (a big screenshot takes ~90 ms to encode), then
    /// appends it. Returns false if the task is full.
    @discardableResult
    func addAttachment(_ image: NSImage, to task: TaskItem) -> Bool {
        guard let index = indexOfTask(task), tasks[index].canAddAttachment else { return false }
        let taskID = task.id
        attachmentStore.save(image) { [weak self] id in
            self?.attachSavedImage(id, toTaskID: taskID)
        }
        return true
    }

    private func attachSavedImage(_ newID: UUID?, toTaskID taskID: UUID) {
        guard let newID else { return }
        // The task was deleted while its image was being saved, or filled
        // up meanwhile (two quick drops): don't leave the file behind.
        guard let index = tasks.firstIndex(where: { $0.id == taskID }), tasks[index].canAddAttachment else {
            attachmentStore.delete(id: newID)
            return
        }
        tasks[index].attachmentIDs.append(newID)
    }

    func removeAttachment(_ attachmentID: UUID, from task: TaskItem) {
        guard let index = indexOfTask(task), tasks[index].attachmentIDs.contains(attachmentID) else { return }
        attachmentStore.delete(id: attachmentID)
        tasks[index].attachmentIDs.removeAll { $0 == attachmentID }
    }

    func removeAllAttachments(for task: TaskItem) {
        guard let index = indexOfTask(task) else { return }
        for id in tasks[index].attachmentIDs {
            attachmentStore.delete(id: id)
        }
        tasks[index].attachmentIDs = []
    }

    func attachmentImage(_ attachmentID: UUID) -> NSImage? {
        attachmentStore.loadImage(for: attachmentID)
    }

    /// The row's small thumbnail; `completion` runs on the main thread.
    func loadAttachmentThumbnail(for attachmentID: UUID, completion: @escaping (NSImage?) -> Void) {
        attachmentStore.loadThumbnail(for: attachmentID, completion: completion)
    }

    func cachedAttachmentThumbnail(for attachmentID: UUID) -> NSImage? {
        attachmentStore.cachedThumbnail(for: attachmentID)
    }

    func attachmentURL(for attachmentID: UUID) -> URL {
        attachmentStore.url(for: attachmentID)
    }

    /// Opens the task's images in Quick Look, starting at `attachmentID`;
    /// the arrow keys go to the others.
    func openAttachment(_ attachmentID: UUID, in task: TaskItem) {
        let ids = tasks.first { $0.id == task.id }?.attachmentIDs ?? task.attachmentIDs
        guard let index = ids.firstIndex(of: attachmentID) else { return }
        AttachmentQuickLook.shared.show(ids.map { attachmentStore.url(for: $0) }, startingAt: index)
    }

    /// Puts an image on the clipboard, as PNG and TIFF so any app can paste
    /// it. Returns false if there's no such image.
    @discardableResult
    func copyAttachment(_ attachmentID: UUID, to pasteboard: NSPasteboard = .general) -> Bool {
        guard let png = try? Data(contentsOf: attachmentStore.url(for: attachmentID)) else { return false }
        let item = NSPasteboardItem()
        item.setData(png, forType: .png)
        if let tiff = NSImage(data: png)?.tiffRepresentation {
            item.setData(tiff, forType: .tiff)
        }
        pasteboard.clearContents()
        return pasteboard.writeObjects([item])
    }

    /// What dragging a task's image out of the card carries: the PNG, plus
    /// a file for apps like Finder. The file is handed over as a copy, so a
    /// drop can never move the attachment out of the app's folder.
    func attachmentDragItem(_ attachmentID: UUID, of task: TaskItem) -> NSItemProvider? {
        let url = attachmentStore.url(for: attachmentID)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let provider = NSItemProvider()
        provider.suggestedName = Self.attachmentFileName(for: task.title)
        provider.registerFileRepresentation(forTypeIdentifier: UTType.png.identifier, fileOptions: [], visibility: .all) { completion in
            completion(url, false, nil)
            return nil
        }
        return provider
    }

    /// "Design popup.png" from the title's first line: marks and characters
    /// file names can't hold removed, kept short.
    static func attachmentFileName(for title: String) -> String {
        let firstLine = title.split(separator: "\n").first.map(String.init) ?? ""
        let plain = String(TaskTitleFormat.inline(firstLine).characters)
        let cleaned = plain
            .components(separatedBy: CharacterSet(charactersIn: "/:\\?%*|\"<>"))
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let short = String(cleaned.prefix(40)).trimmingCharacters(in: .whitespaces)
        return short.isEmpty ? "Image" : short
    }

    /// Removes completed tasks left over from a previous day, keeping today's
    /// completed tasks visible. Returns the number of tasks removed.
    @discardableResult
    func purgeStaleCompletedTasks(referenceDate: Date = Date(), calendar: Calendar = .current) -> Int {
        let staleTasks = tasks.filter { task in
            guard task.isDone else { return false }
            guard let doneAt = task.doneAt else { return true }
            return calendar.isDate(doneAt, inSameDayAs: referenceDate) == false
        }
        guard staleTasks.isEmpty == false else { return 0 }
        // Same as delete(_:): a cleared task takes its image file with it,
        // rather than leaving it behind in the attachments folder.
        for attachmentID in staleTasks.flatMap(\.attachmentIDs) {
            attachmentStore.delete(id: attachmentID)
        }
        let staleIDSet = Set(staleTasks.map(\.id))
        tasks.removeAll { staleIDSet.contains($0.id) }
        return staleTasks.count
    }

    private func load() {
        isLoading = true
        defer { isLoading = false }

        let loaded = persistence.load()
        saved = loaded
        tasks = loaded.tasks
        categories = loaded.categories

        // Ensure old references to removed categories are cleaned up.
        let existingCategoryIDs = Set(categories.map(\.id))
        for index in tasks.indices where tasks[index].categoryID != nil {
            guard let categoryID = tasks[index].categoryID else { continue }
            if existingCategoryIDs.contains(categoryID) == false {
                tasks[index].categoryID = nil
            }
        }

        purgeStaleCompletedTasks()

        // The cleanup above runs while loading, so it isn't saved by the
        // didSets; save it here (a no-op if it changed nothing).
        save()
    }

    /// Saves the list if it changed since the last save, recording what
    /// changed and when.
    private func save() {
        let current = LibrarySnapshot(tasks: tasks, categories: categories, history: saved.history)
        guard current != saved else { return }
        saved = current.recordingChanges(since: saved, at: Date())
        persistence.save(saved)
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

    /// Open (not done) tasks: in total, and per category. Shown as the
    /// counts on the category tabs.
    func openTaskCounts() -> (all: Int, byCategory: [UUID: Int]) {
        var all = 0
        var byCategory: [UUID: Int] = [:]
        for task in tasks where task.isDone == false {
            all += 1
            if let categoryID = task.categoryID {
                byCategory[categoryID, default: 0] += 1
            }
        }
        return (all, byCategory)
    }

    private func normalizedTitle(from raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func indexOfTask(_ task: TaskItem) -> Int? {
        tasks.firstIndex { $0.id == task.id }
    }
}
