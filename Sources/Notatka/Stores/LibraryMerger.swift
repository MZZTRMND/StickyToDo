import Foundation

/// Combines two copies of the task list - this Mac's and one saved by
/// another Mac - into one, using each copy's ChangeHistory:
///
/// - Each task or category is taken from the copy that changed it last.
/// - A deletion wins over any edit made before it, and loses to an edit
///   made after it.
/// - The order comes from the copy that reordered last; items only the
///   other copy has are slotted in after the item they follow there.
///
/// It only combines lists - it doesn't read or write anything - and when
/// the two copies are equally recent, `local` wins.
enum LibraryMerger {
    static func merge(local: LibrarySnapshot, remote: LibrarySnapshot) -> LibrarySnapshot {
        var history = ChangeHistory()
        history.deletedAt = local.history.deletedAt.merging(remote.history.deletedAt, uniquingKeysWith: max)

        let tasks = mergeItems(
            local: local.tasks, localHistory: local.history,
            remote: remote.tasks, remoteHistory: remote.history,
            orderModifiedAt: \.taskOrderModifiedAt, into: &history
        )
        let categories = mergeItems(
            local: local.categories, localHistory: local.history,
            remote: remote.categories, remoteHistory: remote.history,
            orderModifiedAt: \.categoryOrderModifiedAt, into: &history
        )
        return LibrarySnapshot(tasks: tasks, categories: categories, history: history)
    }

    /// `history` comes in holding the merged deletions; this adds the merged
    /// edit times and order time for these items, and clears deletions that
    /// a later edit overrode.
    private static func mergeItems<Item: Identifiable>(
        local: [Item], localHistory: ChangeHistory,
        remote: [Item], remoteHistory: ChangeHistory,
        orderModifiedAt: WritableKeyPath<ChangeHistory, Date?>,
        into history: inout ChangeHistory
    ) -> [Item] where Item.ID == UUID {
        let localByID = Dictionary(local.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let remoteByID = Dictionary(remote.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })

        var kept: [UUID: Item] = [:]
        for id in Set(localByID.keys).union(remoteByID.keys) {
            let localDate = localByID[id] == nil ? nil : localHistory.modifiedAt(id)
            let remoteDate = remoteByID[id] == nil ? nil : remoteHistory.modifiedAt(id)
            let remoteWins = (remoteDate ?? .distantPast) > (localDate ?? .distantPast) || localDate == nil
            guard let item = remoteWins ? remoteByID[id] : localByID[id] else { continue }
            let modified = max(localDate ?? .distantPast, remoteDate ?? .distantPast)

            if let deleted = history.deletedAt[id], deleted >= modified {
                continue
            }
            history.deletedAt[id] = nil
            if modified != .distantPast {
                history.modifiedAt[id] = modified
            }
            kept[id] = item
        }

        // Order: start from the copy that reordered last.
        let localOrderDate = localHistory[keyPath: orderModifiedAt]
        let remoteOrderDate = remoteHistory[keyPath: orderModifiedAt]
        history[keyPath: orderModifiedAt] = [localOrderDate, remoteOrderDate].compactMap { $0 }.max()
        let remoteOrderWins = (remoteOrderDate ?? .distantPast) > (localOrderDate ?? .distantPast)
        let (base, other) = remoteOrderWins ? (remote, local) : (local, remote)

        var orderedIDs = base.map(\.id).filter { kept[$0] != nil }
        var placed = Set(orderedIDs)
        var previousInOther: UUID?
        for id in other.map(\.id) {
            defer { if placed.contains(id) { previousInOther = id } }
            guard kept[id] != nil, placed.contains(id) == false else { continue }
            // After the item it follows in its own copy, or first if it
            // leads that copy (new tasks are added at the top).
            let index = previousInOther.flatMap { orderedIDs.firstIndex(of: $0) }.map { $0 + 1 } ?? 0
            orderedIDs.insert(id, at: index)
            placed.insert(id)
        }
        return orderedIDs.compactMap { kept[$0] }
    }
}
