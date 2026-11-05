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
    /// The attachment's thumbnail (see AttachmentThumbnail).
    let attachmentPreview: AttachmentPreviewSource
    let onOpenAttachment: () -> Void
    /// An image from outside is being dragged over this row.
    let isImageDropTarget: Bool
    let onEditingChanged: (Bool) -> Void
    /// Builds the "…" / right-click menu when it's opened (see TaskMenuBuilder).
    let makeMenu: () -> NSMenu
    @Binding var editTrigger: Bool
    @State private var isCircleHovered = false
    @State private var isRowHovered = false
    @State private var isEditing = false
    @State private var draftTitle = ""
    /// Shift+Return adds a line while editing (for bullet lists).
    @State private var newlineKeyMonitor = NewlineKeyMonitor()
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
                    // Wraps over several lines like the title it replaces, so
                    // a long task keeps its shape while editing instead of
                    // collapsing into one scrolling line. Return still saves;
                    // Shift+Return adds a line (newlineKeyMonitor).
                    TextField("", text: $draftTitle, axis: .vertical)
                        .textFieldStyle(.plain)
                        .font(.system(size: taskFontSize, weight: .medium))
                        .foregroundStyle(textPrimaryColor)
                        .fixedSize(horizontal: false, vertical: true)
                        .focused($isTitleFocused)
                        .onSubmit(commitEdit)
                        .onExitCommand {
                            cancelEdit()
                        }
                } else {
                    formattedTitle
                        .onTapGesture(count: 2) {
                            startEdit()
                        }
                }

                if let attachmentID = task.attachmentID {
                    AttachmentThumbnail(
                        attachmentID: attachmentID,
                        isDone: task.isDone,
                        source: attachmentPreview,
                        onOpen: onOpenAttachment
                    )
                    .padding(.top, 8)
                }

                if isEditing == false, let categoryBadge {
                    Text(categoryBadge.name)
                        .font(.system(size: 12, weight: .regular))
                        .lineLimit(1)
                        .foregroundStyle(metaLineColor)
                        .help(categoryBadge.name)
                        .padding(.top, 4)
                }
            }
            .padding(.leading, showCheckboxes ? 12 : 0)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())

            Group {
                if isEditing {
                    Button(action: commitEdit) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(textPrimaryColor)
                            .frame(width: 32, height: 32)
                            .contentShape(Rectangle())
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
                .fill((isRowHovered || isDragging || isImageDropTarget) ? rowHoverColor : .clear)
                // Scoped to the background alone, so a hover change doesn't
                // re-animate the whole row subtree (including the menu).
                .animation(.easeInOut(duration: 0.18), value: isRowHovered)
                .animation(.easeInOut(duration: 0.18), value: isDragging)
        )
        .overlay {
            if isImageDropTarget {
                imageDropHint
            }
        }
        .animation(.easeInOut(duration: 0.12), value: isImageDropTarget)
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
            if isEditing {
                newlineKeyMonitor.start()
            } else {
                newlineKeyMonitor.stop()
            }
            onEditingChanged(isEditing)
        }
        .onChange(of: isTitleFocused) { _, focused in
            if focused == false {
                commitEdit()
            }
        }
        .onDisappear {
            newlineKeyMonitor.stop()
        }
    }

    /// The title with its light Markdown shown as formatting (see
    /// TaskTitleFormat). A one-line title is a single Text, as before.
    @ViewBuilder
    private var formattedTitle: some View {
        let lines = TaskTitleFormat.lines(from: task.title)
        if lines.count == 1, lines[0].isBullet == false {
            titleText(lines[0].text)
        } else {
            VStack(alignment: .leading, spacing: 2) {
                ForEach(lines.indices, id: \.self) { index in
                    let line = lines[index]
                    if line.isBullet {
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            titleText(AttributedString("•"))
                            titleText(line.text)
                        }
                    } else {
                        titleText(line.text)
                    }
                }
            }
        }
    }

    private func titleText(_ text: AttributedString) -> some View {
        Text(text)
            .font(.system(size: taskFontSize, weight: .medium))
            .foregroundStyle(taskTitleColor)
            .strikethrough(task.isDone, color: taskTitleColor)
            .fixedSize(horizontal: false, vertical: true)
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

    /// Shown while an image is dragged over the row: an accent outline and
    /// what dropping will do - a task holds one image, so a second replaces it.
    private var imageDropHint: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .strokeBorder(cardColors.accent ?? Theme.accent, lineWidth: 1.5)
            .overlay(alignment: .bottomTrailing) {
                Text(task.attachmentID == nil ? "Drop to attach" : "Drop to replace image")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Theme.secondaryText)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 6)
            }
            .allowsHitTesting(false)
            .transition(.opacity)
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
