import SwiftUI
import AppKit

struct TaskRow<RowMenu: View>: View {
    let task: TaskItem
    let showCheckboxes: Bool
    let onToggle: () -> Void
    let onDelete: () -> Void
    let onRename: (String) -> Void
    let categoryBadge: TaskCategoryBadge?
    let isDragging: Bool
    let attachmentImage: NSImage?
    let onOpenAttachment: () -> Void
    let onEditingChanged: (Bool) -> Void
    @ViewBuilder let rowMenu: () -> RowMenu
    @Binding var editTrigger: Bool
    @State private var isCircleHovered = false
    @State private var isRowHovered = false
    @State private var isEditing = false
    @State private var draftTitle = ""
    @State private var isAttachmentHovered = false
    @State private var showAttachmentPreview = false
    @State private var attachmentPreviewTimer = HoverTooltipTimer()
    @FocusState private var isTitleFocused: Bool
    @EnvironmentObject private var settings: AppSettings

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            if showCheckboxes {
                Button(action: onToggle) {
                    Circle()
                        .fill(task.isDone ? Theme.primaryText : .clear)
                        .overlay(
                            Group {
                                if task.isDone == false {
                                    Circle()
                                        .stroke(circleStrokeColor, lineWidth: 2)
                                }
                            }
                        )
                        .frame(width: 20, height: 20)
                        .overlay(
                            Image(systemName: "checkmark")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(task.isDone ? Theme.cardBackground : .clear)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(task.isDone ? "Mark as not done" : "Mark as done")
                .padding(.top, 2)
                .animation(.easeInOut(duration: 0.18), value: isCircleHovered)
                .onHover { hovering in
                    isCircleHovered = hovering
                }
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

                    if attachmentImage != nil || categoryBadge != nil {
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
                    // The Menu stays in the tree and is revealed with opacity
                    // rather than being created on hover: while you scroll,
                    // rows slide under a stationary cursor, so hover-gating
                    // meant repeatedly building and tearing down a real
                    // NSPopUpButton mid-gesture. Created once when the row
                    // mounts is much cheaper than that.
                    ZStack {
                        if task.isImportant {
                            Image(systemName: "flag.fill")
                                .font(.system(size: 14, weight: .regular))
                                .foregroundStyle(Theme.importantRed)
                                .opacity(showEllipsisMenu ? 0 : 1)
                        }

                        Menu {
                            rowMenu()
                        } label: {
                            // A label that's *only* an Image gets handed off to
                            // the native pull-down button's image slot, which
                            // renders it small and black regardless of
                            // font/foregroundStyle - wrapping it forces SwiftUI
                            // to render the label itself, fixing the color.
                            ZStack {
                                Image(systemName: "ellipsis")
                                    .foregroundStyle(Theme.secondaryText)
                                    .accessibilityHidden(true)
                            }
                            .frame(width: 32, height: 32)
                        }
                        .menuStyle(.borderlessButton)
                        .menuIndicator(.hidden)
                        .accessibilityLabel("More actions")
                        .opacity(showEllipsisMenu ? 1 : 0)
                        .allowsHitTesting(showEllipsisMenu)
                    }
                    // Reserves the slot and replaces the Menu's old
                    // .fixedSize(), which made SwiftUI query the popup's
                    // intrinsic size while the popup's own update invalidated
                    // that same intrinsic size.
                    .frame(width: 32, height: 32)
                    .animation(.easeInOut(duration: 0.12), value: isRowHovered)
                }
            }
            .padding(.top, 2)
            .padding(.leading, 8)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        // The row now sizes itself: the title wraps, the VStack grows, and
        // this is only a comfortable floor for short rows. Previously the
        // height was computed by hand (NSString.boundingRect per row) and
        // reported back up via a preference so the window could sum it -
        // that measurement ran for every task on every render and was the
        // main source of the scrolling stall.
        .frame(minHeight: TaskRowMetrics.minimumHeight)
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
            if let attachmentImage {
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
                    if showAttachmentPreview {
                        Image(nsImage: attachmentImage)
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
                HStack(spacing: 3) {
                    Image(systemName: "folder")
                        .font(.system(size: 12, weight: .regular))
                    Text(categoryBadge.name)
                        .font(.system(size: 12, weight: .regular))
                        .lineLimit(1)
                }
                .foregroundStyle(metaLineColor)
                .help(categoryBadge.name)
            }
        }
    }

    private func handleAttachmentHoverChanged(_ hovering: Bool) {
        attachmentPreviewTimer.cancel()
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

/// TaskRow is generic (over its context-menu content), and generic types
/// can't have static stored properties, so this lives outside the type.
enum TaskRowMetrics {
    /// A comfortable floor for a short row. Everything taller than this is
    /// decided by SwiftUI laying the row out normally - the app no longer
    /// measures title text itself.
    static let minimumHeight: CGFloat = 48
}

struct TaskCategoryBadge: Equatable {
    let name: String
}
