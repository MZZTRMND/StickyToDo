import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct ContentView: View {
    @EnvironmentObject private var store: TaskStore
    @EnvironmentObject private var settings: AppSettings
    @State private var isHeaderQuickAddHovered = false
    @State private var isHeaderQuickAddTooltipVisible = false
    @State private var headerQuickAddTooltipTimer = HoverTooltipTimer()
    @State private var draggingId: UUID?
    /// While a task's done state is mid-transition, holds it in its
    /// pre-toggle section (true = keep showing as pending, false = keep
    /// showing as done) for Layout.doneMoveDelay before letting it move to
    /// its new section - symmetric for both completing and un-completing.
    @State private var sectionOverrides: [UUID: Bool] = [:]
    @State private var isDragCursorActive = false
    @State private var windowRef: NSWindow?
    @State private var editingTaskId: UUID?
    @State private var currentlyEditingTaskID: UUID?
    @State private var editPasteImageMonitor = PasteImageMonitor()
    @State private var measuredListContentHeight: CGFloat = 0
    @State private var measuredCategorySectionHeight: CGFloat = 0
    @EnvironmentObject private var categoryUI: CategoryUIState
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let date = Date.now
        let dayNumber = Calendar.current.component(.day, from: date)
        // Computed once here and threaded through. It filters and sorts, and
        // as a plain computed property it used to be re-evaluated ~5x per
        // render (body, the ForEach, and the height math all touched it).
        let tasks = visibleTasks
        ZStack {
            ZStack {
                // Real macOS apps (e.g. Finder) keep the content area opaque
                // and reserve actual glass for toolbar-level controls that
                // float on top of it - mixing a translucent card background
                // with glass tabs on top of it is what produced the seam.
                RoundedRectangle(cornerRadius: Layout.cardCornerRadius, style: .continuous)
                    .fill(cardBackgroundColor)

                // Card-wide drag layer, sitting behind everything else in
                // this ZStack. WindowDragView also appears inside header()
                // below, but confined to that one row - this one covers the
                // rest of the card (margins, gaps around the tabs, the space
                // below the last task) so dragging isn't limited to the
                // couple of truly empty pixels inside the header. Real
                // controls (buttons, chips, task rows) are drawn on top and
                // keep intercepting their own clicks as before.
                WindowDragView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                VStack(spacing: 0) {
                    header(dayNumber: dayNumber, date: date)
                        .padding(.top, Layout.headerSectionTopPadding)
                        .padding(.horizontal, Layout.sectionHorizontalPadding)

                    // Hidden until the first category exists - that one is
                    // created from a task's "..." menu (Move to category).
                    if shouldShowCategorySection {
                        CategorySectionView(categoryUI: categoryUI, draggingId: $draggingId, activateWindow: activateWindow)
                    }
                    if tasks.isEmpty {
                        emptyStateView
                            .frame(height: Layout.emptyStateBottomSpace)
                    } else {
                        list(tasks)
                            .padding(.horizontal, 8)
                    }
                }
                .padding(.top, Layout.cardTopPadding)
                .padding(.horizontal, Layout.cardPadding)
                // The card ZStack's default alignment is .center, so without
                // this, any gap between the computed windowHeight estimate
                // and this VStack's true rendered height (e.g. right after
                // switching to a tab with a different task count) would
                // re-center the whole header/list stack instead of holding
                // the header in place.
                .frame(maxHeight: .infinity, alignment: .top)

                if categoryUI.isCategoryCreationPresented {
                    CategoryCreationOverlay(categoryUI: categoryUI)
                        .transition(.opacity.animation(.easeInOut(duration: 0.18)))
                        .zIndex(4)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: Layout.cardCornerRadius, style: .continuous))
            .overlay(alignment: .topTrailing) {
                if isHeaderQuickAddTooltipVisible {
                    quickAddButtonTooltip
                        .padding(.top, Layout.quickAddTooltipTop)
                        .padding(.trailing, Layout.quickAddTooltipTrailing)
                        .transition(.opacity.combined(with: .scale(scale: 0.96)))
                }
            }
        }
        .frame(minWidth: Layout.cardWidth, maxWidth: 600)
        .frame(height: windowHeight(taskCount: tasks.count))
        .background(
            WindowAccessor { window in
                windowRef = window
            }
        )
        .onTapGesture {
            activateWindow()
        }
        .onChange(of: draggingId) { _, newValue in
            if newValue == nil {
                endDragCursor()
            }
        }
        .onChange(of: store.categories) { _, categories in
            categoryUI.clearSelectionIfMissing(from: categories)
        }
        .onPreferenceChange(ListContentHeightPreferenceKey.self) { height in
            guard abs(height - measuredListContentHeight) > 0.5 else { return }
            measuredListContentHeight = height
        }
        .onPreferenceChange(CategorySectionHeightPreferenceKey.self) { height in
            guard height != measuredCategorySectionHeight else { return }
            measuredCategorySectionHeight = height
        }
        .onChange(of: currentlyEditingTaskID) { _, newValue in
            editPasteImageMonitor.isActive = newValue != nil
        }
        .onAppear {
            editPasteImageMonitor.start { image in
                guard let currentlyEditingTaskID, let task = store.tasks.first(where: { $0.id == currentlyEditingTaskID }) else { return }
                store.setAttachment(image, for: task)
            }
        }
        .onDisappear {
            headerQuickAddTooltipTimer.cancel()
            editPasteImageMonitor.stop()
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 10) {
            VStack(spacing: 2) {
                Text(Layout.emptyStateMessage.line1)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(placeholderTextColor)
                    .multilineTextAlignment(.center)

                Text(Layout.emptyStateMessage.line2)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(placeholderTextColor)
                    .multilineTextAlignment(.center)

                Text(Layout.emptyStateMessage.line3)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(primaryTextColor)
                    .multilineTextAlignment(.center)
                    .padding(.top, 6)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }

    private func header(dayNumber: Int, date: Date) -> some View {
        ZStack {
            WindowDragView()
            HStack {
                VStack(alignment: .leading, spacing: 0) {
                    // .allowsHitTesting(false) on this text: unlike an empty
                    // Spacer, SwiftUI's Text isn't inert to hit-testing on
                    // macOS by default (it's wired into the native text
                    // services/accessibility responder chain), so without
                    // this a click here is claimed by the text itself and
                    // never reaches the WindowDragView layer behind it.
                    HStack(alignment: .center, spacing: Layout.headerInnerSpacing) {
                        Text("\(dayNumber)")
                            .font(.system(size: Layout.dayFontSize, weight: .bold))
                            .foregroundStyle(primaryTextColor)
                            .frame(minHeight: Layout.headerHeight, alignment: .leading)
                            .fixedSize(horizontal: true, vertical: false)
                            .allowsHitTesting(false)
                        VStack(alignment: .leading, spacing: 0) {
                            Text(date, format: .dateTime.weekday(.wide))
                                .font(.system(size: Layout.monthFontSize, weight: .bold))
                                .foregroundStyle(primaryTextColor)
                                .frame(height: Layout.headerLineHeight, alignment: .topLeading)
                                .allowsHitTesting(false)
                            Text(date, format: .dateTime.month(.wide))
                                .font(.system(size: Layout.weekdayFontSize, weight: .regular))
                                .foregroundStyle(primaryTextColor)
                                .frame(height: Layout.headerLineHeight, alignment: .topLeading)
                                .allowsHitTesting(false)
                        }
                    }
                }
                Spacer()

                Button(action: {
                    headerQuickAddTooltipTimer.cancel()
                    isHeaderQuickAddTooltipVisible = false
                    presentQuickAddOverlay()
                }) {
                    Image(systemName: "plus")
                        .font(.system(size: Layout.addIconSize, weight: .medium))
                }
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
                .controlSize(.extraLarge)
                .accessibilityLabel("Add task")
                .scaleEffect(isHeaderQuickAddHovered ? 1.1 : 1.0)
                .animation(
                    .spring(
                        response: Layout.addButtonSpringResponse,
                        dampingFraction: Layout.addButtonSpringDamping
                    ),
                    value: isHeaderQuickAddHovered
                )
                .padding(.top, -25)
                .onHover { hovering in
                    isHeaderQuickAddHovered = hovering
                    handleHeaderQuickAddHoverChanged(hovering)
                }
            }
            .frame(height: Layout.headerHeight, alignment: .top)
            .padding(.trailing, Layout.headerTrailingPadding)
        }
        .frame(height: Layout.headerHeight, alignment: .top)
        .contextMenu {
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
        }
    }

    private func list(_ tasks: [TaskItem]) -> some View {
        ScrollView {
            LazyVStack(spacing: Layout.listRowSpacing) {
                ForEach(tasks) { task in
                    taskRowView(for: task)
                }
            }
            .padding(.top, Layout.listTopPadding)
            .padding(.bottom, Layout.listBottomPadding)
            // One measurement of the whole laid-out stack, which is all the
            // window sizing needs - LazyVStack accounts for rows that aren't
            // mounted yet, so this stays correct while scrolling.
            .background(
                GeometryReader { proxy in
                    Color.clear
                        .preference(key: ListContentHeightPreferenceKey.self, value: proxy.size.height)
                }
            )
        }
        .scrollIndicators(.hidden)
        .scrollEdgeEffectStyle(.soft, for: .top)
        .scrollEdgeEffectStyle(.soft, for: .bottom)
        // Keyed on the count rather than the whole task array, which had to
        // diff every TaskItem on every render.
        .animation(.easeInOut(duration: 0.1), value: tasks.count)
        .frame(maxHeight: Layout.listMaxHeight)
        .onDisappear {
            endDragCursor()
        }
    }

    @ViewBuilder
    private func listItem(for task: TaskItem) -> some View {
        TaskRow(
            task: task,
            showCheckboxes: settings.showCheckboxes,
            onToggle: { toggleDoneWithDelay(taskID: task.id) },
            onDelete: { store.delete(task) },
            onRename: { store.updateTitle(for: task, title: $0) },
            categoryBadge: categoryBadge(for: task),
            isDragging: draggingId == task.id,
            attachmentImage: store.attachmentImage(for: task),
            onOpenAttachment: { store.openAttachment(for: task) },
            onEditingChanged: { isEditing in
                if isEditing {
                    currentlyEditingTaskID = task.id
                } else if currentlyEditingTaskID == task.id {
                    currentlyEditingTaskID = nil
                }
            },
            rowMenu: { rowContextMenu(for: task) },
            editTrigger: taskEditBinding(for: task.id)
        )
    }

    @ViewBuilder
    private func taskRowView(for task: TaskItem) -> some View {
        listItem(for: task)
            .id(task.id)
            .opacity(draggingId == task.id ? 0.4 : 1.0)
            .onDrag {
                beginDragCursor()
                draggingId = task.id
                return NSItemProvider(object: task.id.uuidString as NSString)
            }
            .onDrop(of: [.text, .image], delegate: ReorderDropDelegate(target: task, store: store, draggingId: $draggingId))
            .contextMenu {
                rowContextMenu(for: task)
            }
    }

    private func toggleDoneWithDelay(taskID: UUID) {
        guard let currentTask = store.tasks.first(where: { $0.id == taskID }) else { return }

        let wasDone = currentTask.isDone
        sectionOverrides[taskID] = wasDone == false
        withAnimation(.easeInOut(duration: 0.2)) {
            store.toggleDone(for: currentTask)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + Layout.doneMoveDelay) {
            withAnimation(.easeInOut(duration: 0.22)) {
                _ = sectionOverrides.removeValue(forKey: taskID)
            }
        }
    }

    private func activateWindow() {
        NSApp.activate(ignoringOtherApps: true)
        windowRef?.makeKeyAndOrderFront(nil)
        windowRef?.makeKey()
    }

    private func presentQuickAddOverlay() {
        NotificationCenter.default.post(name: .stickyToDoPresentQuickAddRequested, object: nil)
    }

    private func handleHeaderQuickAddHoverChanged(_ hovering: Bool) {
        headerQuickAddTooltipTimer.cancel()

        guard hovering else {
            withAnimation(.easeOut(duration: 0.12)) {
                isHeaderQuickAddTooltipVisible = false
            }
            return
        }

        headerQuickAddTooltipTimer.scheduleShow {
            guard isHeaderQuickAddHovered else { return }
            withAnimation(.easeInOut(duration: 0.15)) {
                isHeaderQuickAddTooltipVisible = true
            }
        }
    }

    private func beginDragCursor() {
        guard isDragCursorActive == false else { return }
        NSCursor.closedHand.push()
        isDragCursorActive = true
    }

    private func endDragCursor() {
        guard isDragCursorActive else { return }
        NSCursor.pop()
        isDragCursorActive = false
    }

    @ViewBuilder
    private func rowContextMenu(for task: TaskItem) -> some View {
        Button {
            toggleDoneWithDelay(taskID: task.id)
        } label: {
            Label(task.isDone ? "Unmark as done" : "Mark as done", systemImage: "checkmark.circle")
        }

        Button {
            store.setImportant(task.isImportant == false, for: task)
        } label: {
            Label(task.isImportant ? "Unmark as important" : "Mark as important", systemImage: "exclamationmark.circle")
        }
        Divider()

        Menu {
            Button {
                store.assignCategory(nil, to: task)
            } label: {
                if task.categoryID == nil {
                    Label("No category", systemImage: "checkmark")
                } else {
                    Text("No category")
                }
            }

            if store.categories.isEmpty == false {
                Divider()
            }

            if store.categories.isEmpty {
                Button {
                    categoryUI.beginCategoryCreation(for: task.id)
                    activateWindow()
                } label: {
                    Label("Create new category", systemImage: "plus")
                }
            } else {
                ForEach(store.categories) { category in
                    Button {
                        store.assignCategory(category.id, to: task)
                    } label: {
                        if task.categoryID == category.id {
                            Label(category.name, systemImage: "checkmark")
                        } else {
                            Text(category.name)
                        }
                    }
                }
                Divider()
                Button {
                    categoryUI.beginCategoryCreation(for: task.id)
                    activateWindow()
                } label: {
                    Label("Create new category", systemImage: "plus")
                }
            }
        } label: {
            Label("Move to category", systemImage: "tag")
        }

        if hasPasteboardImage {
            Button {
                guard let image = pasteboardImage else { return }
                store.setAttachment(image, for: task)
            } label: {
                Label("Paste Image", systemImage: "photo")
            }
        }
        if task.attachmentID != nil {
            Button {
                store.removeAttachment(for: task)
            } label: {
                Label("Remove Attachment", systemImage: "paperclip")
            }
        }
        Divider()

        Button {
            editingTaskId = task.id
            activateWindow()
        } label: {
            Label("Edit task", systemImage: "pencil")
        }
        Button {
            store.delete(task)
        } label: {
            Label("Delete task", systemImage: "trash")
        }
    }

    /// Cheap check for the menu item's visibility. readObjects() actually
    /// decodes the image, which is far too expensive to run while building
    /// menu content on every render; canReadObject only inspects the
    /// pasteboard's declared types. The decode happens in the action instead.
    private var hasPasteboardImage: Bool {
        NSPasteboard.general.canReadObject(forClasses: [NSImage.self], options: nil)
    }

    private var pasteboardImage: NSImage? {
        NSPasteboard.general.readObjects(forClasses: [NSImage.self], options: nil)?.first as? NSImage
    }

    private func taskEditBinding(for id: UUID) -> Binding<Bool> {
        Binding(
            get: { editingTaskId == id },
            set: { isEditing in
                if isEditing {
                    editingTaskId = id
                } else if editingTaskId == id {
                    editingTaskId = nil
                }
            }
        )
    }

}

private extension ContentView {
    var visibleTasks: [TaskItem] {
        visiblePendingTasks + visibleDoneTasks
    }

    var visiblePendingTasks: [TaskItem] {
        filteredTasks.filter { sectionOverrides[$0.id] ?? ($0.isDone == false) }
    }

    var visibleDoneTasks: [TaskItem] {
        filteredTasks
            .filter { (sectionOverrides[$0.id].map { $0 == false }) ?? $0.isDone }
            .sorted { lhs, rhs in
                let leftDate = lhs.doneAt ?? lhs.createdAt
                let rightDate = rhs.doneAt ?? rhs.createdAt
                if leftDate != rightDate {
                    return leftDate > rightDate
                }
                return lhs.createdAt > rhs.createdAt
            }
    }

    var filteredTasks: [TaskItem] {
        guard let selectedCategoryID = categoryUI.selectedCategoryID else { return store.tasks }
        return store.tasks.filter { $0.categoryID == selectedCategoryID }
    }

    var primaryTextColor: Color {
        Theme.primaryText
    }

    var placeholderTextColor: Color {
        Theme.placeholderText
    }

    var cardBackgroundColor: Color {
        Theme.cardBackground
    }

    /// Height the window should adopt. The list portion now comes from one
    /// measurement of the laid-out content (see ListContentHeightPreferenceKey)
    /// instead of the app re-deriving every row's height from its text on
    /// every render, which is what made scrolling stall.
    func windowHeight(taskCount: Int) -> CGFloat {
        let listHeight: CGFloat
        if taskCount == 0 {
            listHeight = Layout.emptyStateBottomSpace
        } else if measuredListContentHeight > 0 {
            listHeight = min(Layout.listMaxHeight, measuredListContentHeight)
        } else {
            // First frame only, before the measurement lands.
            listHeight = Layout.listMaxHeight
        }
        let dynamicHeight = Layout.cardTopPadding
            + Layout.headerSectionTopPadding
            + Layout.headerHeight
            + categorySectionHeight
            + listHeight
        return taskCount == 0 ? dynamicHeight : min(Layout.maxHeight, dynamicHeight)
    }

    var shouldShowCategorySection: Bool {
        store.categories.isEmpty == false
    }

    var categorySectionHeight: CGFloat {
        guard shouldShowCategorySection else { return 0 }
        // CategorySectionView reports its own real height via
        // CategorySectionHeightPreferenceKey - using that keeps this in sync
        // automatically instead of a hand-maintained constant that can go
        // stale (which is exactly what left a gap at the bottom of the list
        // after the row's vertical padding was removed but this estimate
        // wasn't updated to match). The fallback below is only a first-frame
        // placeholder, before the real measurement has landed.
        guard measuredCategorySectionHeight > 0 else {
            return Layout.inputToCategorySpacing + Layout.categoryBarHeight
        }
        return measuredCategorySectionHeight
    }

    var showCategoryBadges: Bool {
        categoryUI.selectedCategoryID == nil
    }

    func categoryBadge(for task: TaskItem) -> TaskCategoryBadge? {
        guard showCategoryBadges else { return nil }
        guard let category = store.category(for: task.categoryID) else { return nil }
        return TaskCategoryBadge(name: category.name)
    }


    var quickAddButtonTooltip: some View {
        Text("Press \(GlobalHotKeyManager.quickAddShortcutDisplay) to add a task")
            .font(.system(size: 12, weight: .regular))
            .foregroundStyle(Theme.primaryText)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Theme.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(Theme.separator, lineWidth: 1)
                    )
            )
            .shadow(color: Theme.shadow(for: colorScheme), radius: 10, x: 0, y: 4)
            .fixedSize()
    }

}

private enum Layout {
    static let cardCornerRadius: CGFloat = 40
    static let cardWidth: CGFloat = 400
    static let cardTopPadding: CGFloat = 0
    static let cardPadding: CGFloat = 0
    static let sectionHorizontalPadding: CGFloat = 16
    static let headerSectionTopPadding: CGFloat = 16

    static let maxHeight: CGFloat = 600

    static let headerHeight: CGFloat = 60
    static let headerLineHeight: CGFloat = 24
    static let headerTrailingPadding: CGFloat = 0
    static let headerInnerSpacing: CGFloat = 8

    static let dayFontSize: CGFloat = 56
    static let monthFontSize: CGFloat = 20
    static let weekdayFontSize: CGFloat = 20

    static let addIconSize: CGFloat = 20
    static let addButtonSpringResponse: CGFloat = 0.28
    static let addButtonSpringDamping: CGFloat = 0.7
    static let quickAddTooltipTop: CGFloat = 40
    static let quickAddTooltipTrailing: CGFloat = 8

    static let inputToCategorySpacing: CGFloat = 12
    /// Only a placeholder for the single frame before
    /// CategorySectionHeightPreferenceKey's real measurement lands - doesn't
    /// need to stay precisely in sync with the actual row height anymore.
    static let categoryBarHeight: CGFloat = 32

    static let listRowSpacing: CGFloat = 4
    static let listTopPadding: CGFloat = 16
    static let listBottomPadding: CGFloat = 16
    static let listMaxHeight: CGFloat = 600
    static let doneMoveDelay: TimeInterval = 0.30
    static let emptyStateBottomSpace: CGFloat = 100

    static let emptyStateMessage = EmptyStateMessage(
        title: "All clear.",
        line1: "Nothing on your plate today.",
        line2: "Add something or enjoy the quiet.",
        line3: "Press \(GlobalHotKeyManager.quickAddShortcutDisplay) to add a task."
    )
}

/// Carries the laid-out task list's total height up to ContentView so the
/// window can size itself without the app measuring any text on its own.
private struct ListContentHeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    /// max, not "last wins": the default is 0, so reducing with nextValue()
    /// let a sibling's default silently overwrite the real measurement.
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

private struct EmptyStateMessage {
    let title: String
    let line1: String
    let line2: String
    let line3: String
}
