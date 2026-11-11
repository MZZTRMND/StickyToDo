import Foundation

/// Everything StickyToDo saves about the task list: the tasks, in their
/// order, and the categories. Image files are separate (AttachmentStore);
/// tasks only refer to them by id.
struct LibrarySnapshot: Equatable {
    var tasks: [TaskItem]
    var categories: [TaskCategory]

    static let empty = LibrarySnapshot(tasks: [], categories: [])
}

/// Where the task list is kept. TaskStore owns the list and its editing
/// rules; a persistence only reads and writes snapshots of it, so the list
/// can live on this Mac (UserDefaultsPersistence) or somewhere shared
/// without TaskStore knowing the difference.
protocol LibraryPersistence: AnyObject {
    /// The saved list, or an empty one if nothing has been saved yet or it
    /// can't be read.
    func load() -> LibrarySnapshot

    /// Saves the list. Called after every change, so implementations should
    /// skip writes that wouldn't change anything.
    func save(_ snapshot: LibrarySnapshot)
}
