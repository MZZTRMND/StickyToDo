import Foundation

/// When each part of the task list last changed - what LibraryMerger needs
/// to combine two copies of the list edited on different Macs.
///
/// Kept beside the tasks and categories rather than inside them, so the
/// models stay plain and only the saving step deals with it.
struct ChangeHistory: Codable, Equatable {
    /// When each task or category was created or last edited, by id.
    var modifiedAt: [UUID: Date] = [:]
    /// When each task or category was deleted, by id. Without these a copy
    /// that still has the item would bring it back.
    var deletedAt: [UUID: Date] = [:]
    /// When tasks were last moved relative to each other.
    var taskOrderModifiedAt: Date?
    /// When categories were last moved relative to each other.
    var categoryOrderModifiedAt: Date?

    /// How long a deletion is remembered. A Mac that's been away from the
    /// list for longer may bring a deleted item back.
    static let deletionRetention: TimeInterval = 90 * 86_400

    /// Items with no recorded change - lists saved before history was kept -
    /// count as older than any recorded one.
    func modifiedAt(_ id: UUID) -> Date {
        modifiedAt[id] ?? .distantPast
    }
}

extension LibrarySnapshot {
    /// This snapshot, with its history updated for everything that differs
    /// from `previous`: added or edited items get `date`, removed ones are
    /// recorded as deleted, and a change in the tasks' relative order is
    /// recorded too. Adding or removing items alone doesn't count as
    /// reordering.
    func recordingChanges(since previous: LibrarySnapshot, at date: Date) -> LibrarySnapshot {
        var history = previous.history
        Self.record(tasks, since: previous.tasks, at: date, in: &history, orderModifiedAt: \.taskOrderModifiedAt)
        Self.record(categories, since: previous.categories, at: date, in: &history, orderModifiedAt: \.categoryOrderModifiedAt)
        history.deletedAt = history.deletedAt.filter { date.timeIntervalSince($0.value) < ChangeHistory.deletionRetention }

        var recorded = self
        recorded.history = history
        return recorded
    }

    private static func record<Item: Identifiable & Equatable>(
        _ items: [Item],
        since previousItems: [Item],
        at date: Date,
        in history: inout ChangeHistory,
        orderModifiedAt: WritableKeyPath<ChangeHistory, Date?>
    ) where Item.ID == UUID {
        let previousByID = Dictionary(previousItems.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let currentIDs = Set(items.map(\.id))

        for item in items where previousByID[item.id] != item {
            history.modifiedAt[item.id] = date
            history.deletedAt[item.id] = nil
        }
        for previous in previousItems where currentIDs.contains(previous.id) == false {
            history.modifiedAt[previous.id] = nil
            history.deletedAt[previous.id] = date
        }

        let keptBefore = previousItems.map(\.id).filter(currentIDs.contains)
        let keptNow = items.map(\.id).filter { previousByID[$0] != nil }
        if keptBefore != keptNow {
            history[keyPath: orderModifiedAt] = date
        }
    }
}
