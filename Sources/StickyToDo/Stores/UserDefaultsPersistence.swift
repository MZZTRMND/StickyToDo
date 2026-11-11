import Foundation

/// Keeps the task list on this Mac only, as JSON blobs in UserDefaults.
/// Tasks and categories use the keys StickyToDo has always used, so
/// existing lists load unchanged; the change history has a key of its own,
/// which older versions simply ignore.
final class UserDefaultsPersistence: LibraryPersistence {
    static let taskStorageKey = "StickyToDo.tasks"
    static let categoryStorageKey = "StickyToDo.categories"
    static let historyStorageKey = "StickyToDo.changeHistory"

    private let defaults: UserDefaults
    /// What's already stored, so an unchanged part isn't written again.
    private var lastSavedTaskData: Data?
    private var lastSavedCategoryData: Data?
    private var lastSavedHistoryData: Data?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> LibrarySnapshot {
        let taskData = defaults.data(forKey: Self.taskStorageKey)
        let categoryData = defaults.data(forKey: Self.categoryStorageKey)
        let historyData = defaults.data(forKey: Self.historyStorageKey)
        lastSavedTaskData = taskData
        lastSavedCategoryData = categoryData
        lastSavedHistoryData = historyData
        return LibrarySnapshot(
            tasks: Self.decode([TaskItem].self, from: taskData) ?? [],
            categories: Self.decode([TaskCategory].self, from: categoryData) ?? [],
            history: Self.decode(ChangeHistory.self, from: historyData) ?? ChangeHistory()
        )
    }

    func save(_ snapshot: LibrarySnapshot) {
        write(snapshot.tasks, forKey: Self.taskStorageKey, lastSaved: &lastSavedTaskData)
        write(snapshot.categories, forKey: Self.categoryStorageKey, lastSaved: &lastSavedCategoryData)
        write(snapshot.history, forKey: Self.historyStorageKey, lastSaved: &lastSavedHistoryData)
    }

    private func write<Value: Encodable>(_ value: Value, forKey key: String, lastSaved: inout Data?) {
        // An encoding failure keeps the last saved copy rather than crashing.
        guard let data = try? JSONEncoder().encode(value), data != lastSaved else { return }
        defaults.set(data, forKey: key)
        lastSaved = data
    }

    /// nil for missing or unreadable data; load() falls back to empty.
    private static func decode<Value: Decodable>(_ type: Value.Type, from data: Data?) -> Value? {
        guard let data else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
}
