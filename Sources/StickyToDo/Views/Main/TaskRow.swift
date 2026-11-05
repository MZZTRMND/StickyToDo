import SwiftUI
import AppKit

struct TaskRow: View {
    let task: TaskItem
    let showCheckboxes: Bool
    let onToggle: () -> Void
    let onDelete: () -> Void
    let onRename: (String) -> Void
    let categoryBadge: TaskCategoryBadge?
    let isDragging: Bool
    /// Loads the attachment's small preview image (see AttachmentStore).
    let loadAttachmentPreview: (UUID, @escaping (NSImage?) -> Void) -> Void
    let onOpenAttachment: () -> Void
    let onEditingChanged: (Bool) -> Void
    /// Builds the "…" / right-click menu when it's opened (see TaskMenuBuilder).
    let makeMenu: () -> NSMenu
    @Binding var editTrigger: Bool
    @State private var isCircleHovered = false
    @State private var isRowHovered = false
    @State private var isEditing = false
    @State private var draftTitle = ""
    @State private var isAttachmentHovered = false
    @State private var showAttachmentPreview = false
    /// Loaded when the pointer first reaches "Image", not when the row is built.
    @State private var previewImage: NSImage?
    @State private var attachmentPreviewTimer = HoverTooltipTimer()
    @FocusState private var isTitleFocused: Bool
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.cardColors) private var cardColors

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            if showCheckboxes {
                checkbox
            }

            VStack(alignment: .leading, spacing: 0) {
                if isEditing {
                    TextField("", text: $draftTitle)
                        .textFieldStyle(.plain)
                        .font(.system(size: taskFontSize, weight: .medium))
                        .foregroundStyle(textPrimaryColor)
                        .focused($isTitleFocused)
                        .onSubmit(commitEdit)
                        .onExitCommand {
                            cancelEdit()
                        }
                } else {
                    Text(task.title)
                        .font(.system(size: taskFontSize, weight: .medium))
                        .foregroundStyle(taskTitleColor)
                        .strikethrough(task.isDone, color: taskTitleColor)
                        .fixedSize(horizontal: false, vertical: true)
                        .onTapGesture(count: 2) {
                            startEdit()
                        }

                    if task.attachmentID != nil || categoryBadge != nil {
                        metaLine
                            .padding(.top, 4)
                    }
                }
            }
            .padding(.leading, showCheckboxes ? 12 : 0)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())

            Group {
                if isEditing {
                    Button(action: commitEdit) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(textPrimaryColor)
                            .frame(width: 16, height: 16)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Finish editing")
                } else {
                    // Flag and "..." share one slot: the flag shows at rest,
                    // and hovering crossfades the menu in over it.
                    //
                    ZStack {
                        if task.isImportant {
                            Image(systemName: "flag.fill")
                                .font(.system(size: 14, weight: .regular))
                                .foregroundStyle(Theme.importantRed)
                                .opacity(showEllipsisMenu ? 0 : 1)
                        }

                        // A plain icon; the menu is built when it's clicked.
                        Image(systemName: "ellipsis")
                            .foregroundStyle(Theme.secondaryText)
                            .frame(width: 32, height: 32)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                makeMenu().popUp(positioning: nil, at: NSEvent.mouseLocation, in: nil)
                            }
                            .accessibilityElement()
                            .accessibilityLabel("More actions")
                            .accessibilityAddTraits(.isButton)
                            .accessibilityAction { makeMenu().popUp(positioning: nil, at: NSEvent.mouseLocation, in: nil) }
                            .opacity(showEllipsisMenu ? 1 : 0)
                            .allowsHitTesting(showEllipsisMenu)
                    }
                    // Reserves the slot, so the title wraps the same with or without the flag.
                    .frame(width: 32, height: 32)
                    .animation(.easeInOut(duration: 0.12), value: isRowHovered)
                }
            }
            .padding(.top, 2)
            .padding(.leading, 8)
        }
        .padding(.vertical, settings.cardStyle.density.rowVerticalPadding)
        .padding(.horizontal, 16)
        // The row now sizes itself: the title wraps, the VStack grows, and
        // this is only a comfortable floor for short rows. Previously the
        // height was computed by hand (NSString.boundingRect per row) and
        // reported back up via a preference so the window could sum it -
        // that measurement ran for every task on every render and was the
        // main source of the scrolling stall.
        .frame(minHeight: settings.cardStyle.density.rowMinimumHeight)
        .contentShape(Rectangle())
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill((isRowHovered || isDragging) ? rowHoverColor : .clear)
                // Scoped to the background alone, so a hover change doesn't
                // re-animate the whole row subtree (including the menu).
                .animation(.easeInOut(duration: 0.18), value: isRowHovered)
                .animation(.easeInOut(duration: 0.18), value: isDragging)
        )
        .onTapGesture {
            guard isEditing == false else { return }
            onToggle()
        }
        // Right-click menu. Left off while editing, so the text field keeps
        // its own Cut/Copy/Paste menu.
        .overlay {
            if isEditing == false {
                RightClickMenuArea(makeMenu: makeMenu)
            }
        }
        .onHover { hovering in
            isRowHovered = hovering
        }
        .onChange(of: task.attachmentID) {
            previewImage = nil
            showAttachmentPreview = false
        }
        .onChange(of: task.isDone) {
            isRowHovered = false
            isCircleHovered = false
        }
        .onChange(of: editTrigger) { _, shouldEdit in
            guard shouldEdit else { return }
            startEdit()
            editTrigger = false
        }
        .onChange(of: isEditing) { _, isEditing in
            onEditingChanged(isEditing)
        }
        .onChange(of: isTitleFocused) { _, focused in
            if focused == false {
                commitEdit()
            }
        }
        .onDisappear {
            attachmentPreviewTimer.cancel()
        }
    }

    /// A drawn circle, not a Button: clicking anywhere on the row already
    /// checks the task off (see .onTapGesture in body), and a button per row
    /// made every row ~4 ms more expensive to build.
    private var checkbox: some View {
        let circle = Circle()
            .fill(task.isDone ? checkedFill : .clear)
            .overlay {
                if task.isDone == false {
                    Circle().stroke(circleStrokeColor, lineWidth: 2)
                }
            }
            .frame(width: 20, height: 20)
            .overlay {
                Image(systemName: "checkmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(task.isDone ? checkmarkColor : .clear)
            }
        return circle
            .contentShape(Circle())
            .accessibilityElement()
            .accessibilityLabel(task.isDone ? "Mark as not done" : "Mark as done")
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { onToggle() }
            .padding(.top, 2)
            .animation(.easeInOut(duration: 0.18), value: isCircleHovered)
            .onHover { hovering in
                isCircleHovered = hovering
            }
    }

    /// A checked task's circle: the card style's accent, or the text color.
    private var checkedFill: Color {
        cardColors.accent ?? Theme.primaryText
    }

    /// The tick inside it: white on an accent, otherwise the card color, which
    /// contrasts with the text color by definition.
    private var checkmarkColor: Color {
        cardColors.accent == nil ? cardColors.background : .white
    }

    private var circleStrokeColor: Color {
        if task.isDone {
            return Theme.primaryText
        }
        return isCircleHovered ? Theme.primaryText : Theme.tertiaryText
    }

    private var textPrimaryColor: Color {
        Theme.primaryText
    }

    private var taskTitleColor: Color {
        task.isDone ? completedTextColor : textPrimaryColor
    }

    private var taskFontSize: CGFloat {
        CGFloat(settings.taskFontSize)
    }

    private var rowHoverColor: Color {
        Theme.hoverFill
    }

    private var showEllipsisMenu: Bool {
        isRowHovered && isDragging == false
    }

    private var completedTextColor: Color {
        Theme.tertiaryText
    }

    private var metaLineColor: Color {
        task.isDone ? completedTextColor : Theme.secondaryText
    }

    @ViewBuilder
    private var metaLine: some View {
        HStack(spacing: 4) {
            if task.attachmentID != nil {
                HStack(spacing: 3) {
                    Image(systemName: "paperclip")
                        .font(.system(size: 12, weight: .regular))
                    Text("Image")
                        .font(.system(size: 12, weight: .regular))
                }
                .foregroundStyle(metaLineColor)
                .contentShape(Rectangle())
                .onHover { hovering in
                    isAttachmentHovered = hovering
                    handleAttachmentHoverChanged(hovering)
                    if hovering {
                        NSCursor.pointingHand.set()
                    } else {
                        NSCursor.arrow.set()
                    }
                }
                .onTapGesture {
                    onOpenAttachment()
                }
                .overlay(alignment: .topLeading) {
                    if showAttachmentPreview, let previewImage {
                        Image(nsImage: previewImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 120, height: 120)
                            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .offset(y: -130)
                            .transition(.opacity)
                    }
                }
                .accessibilityLabel("View attachment")

                if categoryBadge != nil {
                    Text("·")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(metaLineColor)
                }
            }

            if let categoryBadge {
                Text(categoryBadge.name)
                    .font(.system(size: 12, weight: .regular))
                    .lineLimit(1)
                    .foregroundStyle(metaLineColor)
                    .help(categoryBadge.name)
            }
        }
    }

    private func handleAttachmentHoverChanged(_ hovering: Bool) {
        attachmentPreviewTimer.cancel()
        if hovering, previewImage == nil, let attachmentID = task.attachmentID {
            // Has the hover delay (1 s) to arrive, so it's normally ready in time.
            loadAttachmentPreview(attachmentID) { image in
                guard task.attachmentID == attachmentID else { return }
                previewImage = image
            }
        }
        if hovering == false {
            withAnimation(.easeOut(duration: 0.12)) {
                showAttachmentPreview = false
            }
            return
        }

        attachmentPreviewTimer.scheduleShow {
            guard isAttachmentHovered else { return }
            withAnimation(.easeInOut(duration: 0.15)) {
                showAttachmentPreview = true
            }
        }
    }

    private func startEdit() {
        draftTitle = task.title
        isEditing = true
        isTitleFocused = true
    }

    private func commitEdit() {
        guard isEditing else { return }
        let trimmedTitle = draftTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedTitle.isEmpty == false && trimmedTitle != task.title {
            onRename(trimmedTitle)
        }
        isEditing = false
    }

    private func cancelEdit() {
        isEditing = false
        draftTitle = task.title
    }

}

struct TaskCategoryBadge: Equatable {
    let name: String
}
