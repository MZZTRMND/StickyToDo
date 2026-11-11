import Foundation

/// Keeps the task list on this Mac only, as two JSON blobs in UserDefaults -
/// the format StickyToDo has always used, so existing lists load unchanged.
final class UserDefaultsPersistence: LibraryPersistence {
    static let taskStorageKey = "StickyToDo.tasks"
    static let categoryStorageKey = "StickyToDo.categories"

    private let defaults: UserDefaults
    /// What's already stored, so an unchanged part isn't written again.
    private var lastSavedTaskData: Data?
    private var lastSavedCategoryData: Data?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> LibrarySnapshot {
        let taskData = defaults.data(forKey: Self.taskStorageKey)
        let categoryData = defaults.data(forKey: Self.categoryStorageKey)
        lastSavedTaskData = taskData
        lastSavedCategoryData = categoryData
        return LibrarySnapshot(
            tasks: Self.decode([TaskItem].self, from: taskData),
            categories: Self.decode([TaskCategory].self, from: categoryData)
        )
    }

    func save(_ snapshot: LibrarySnapshot) {
        write(snapshot.tasks, forKey: Self.taskStorageKey, lastSaved: &lastSavedTaskData)
        write(snapshot.categories, forKey: Self.categoryStorageKey, lastSaved: &lastSavedCategoryData)
    }

    private func write<Value: Encodable>(_ value: Value, forKey key: String, lastSaved: inout Data?) {
        // An encoding failure keeps the last saved copy rather than crashing.
        guard let data = try? JSONEncoder().encode(value), data != lastSaved else { return }
        defaults.set(data, forKey: key)
        lastSaved = data
    }

    /// Missing or unreadable data loads as an empty list.
    private static func decode<Value: Decodable & RangeReplaceableCollection>(_ type: Value.Type, from data: Data?) -> Value {
        guard let data else { return Value() }
        return (try? JSONDecoder().decode(type, from: data)) ?? Value()
    }
}
