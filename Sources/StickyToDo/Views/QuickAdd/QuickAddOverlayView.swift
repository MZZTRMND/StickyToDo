import AppKit
import Combine
import SwiftUI

struct QuickAddOverlayView: View {
    let onSubmit: (String, UUID?, NSImage?) -> Void
    let onClose: () -> Void

    @EnvironmentObject private var store: TaskStore
    @EnvironmentObject private var categoryUI: CategoryUIState
    @State private var text = ""
    @State private var chosenCategoryID: UUID?
    @State private var pendingImage: NSImage?
    @State private var pasteImageMonitor = PasteImageMonitor()
    @State private var isPendingImageHovered = false
    @State private var showPendingImagePreview = false
    @State private var pendingImagePreviewTimer = HoverTooltipTimer()
    @State private var isButtonHovered = false
    @State private var shakeTrigger: CGFloat = 0
    @State private var isAnimatingIn = false
    @State private var isClosing = false
    @State private var placeholderIndex = 0
    @FocusState private var isInputFocused: Bool
    private let placeholderTimer = Timer.publish(every: 5.0, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            Color.black.opacity(isAnimatingIn ? 0.10 : 0.0)
                .ignoresSafeArea()
                .onTapGesture {
                    dismissOverlay()
                }

            HStack(spacing: 10) {
                ZStack(alignment: .leading) {
                    if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text(Layout.rotatingPlaceholders[placeholderIndex])
                            .id(placeholderIndex)
                            .font(.system(size: 24, weight: .regular))
                            .foregroundStyle(placeholderTextColor)
                            .transition(.opacity)
                            .animation(.easeInOut(duration: 0.25), value: placeholderIndex)
                    }

                    TextField("", text: $text)
                        .textFieldStyle(.plain)
                        .font(.system(size: 24, weight: .regular))
                        .foregroundStyle(textColor)
                }
                .focused($isInputFocused)
                .onSubmit(submit)
                .onExitCommand {
                    dismissOverlay()
                }
                .padding(.leading, 32)

                if let pendingImage {
                    Image(systemName: "paperclip")
                        .font(.system(size: 20, weight: .regular))
                        .foregroundStyle(pendingImageIconColor)
                        .frame(width: 40, height: 40)
                        .contentShape(Rectangle())
                        .scaleEffect(isPendingImageHovered ? 1.1 : 1.0)
                        .animation(
                            .spring(response: 0.28, dampingFraction: 0.7),
                            value: isPendingImageHovered
                        )
                        .onHover { hovering in
                            isPendingImageHovered = hovering
                            handlePendingImageHoverChanged(hovering)
                            if hovering {
                                NSCursor.pointingHand.set()
                            } else {
                                NSCursor.arrow.set()
                            }
                        }
                        .overlay(alignment: .top) {
                            if showPendingImagePreview {
                                Image(nsImage: pendingImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 140, height: 140)
                                    .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                                    .offset(y: -150)
                                    .transition(.opacity)
                            }
                        }
                        .transition(.opacity)
                        .accessibilityLabel("Image attached")
                }

                if store.categories.isEmpty == false {
                    categoryPicker
                }

                Button(action: submit) {
                    Image(systemName: "plus")
                        .font(.system(size: 28, weight: .medium))
                        .foregroundStyle(Theme.primaryText)
                        .frame(width: 56, height: 56)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Add task")
                .scaleEffect(isButtonHovered ? 1.05 : 1.0)
                .animation(.easeInOut(duration: 0.12), value: isButtonHovered)
                .onHover { hovering in
                    isButtonHovered = hovering
                }
                .padding(.trailing, 16)
            }
            .frame(width: 620, height: 84)
            // A genuinely floating surface, so glassEffect is the right API
            // here (unlike on buttons, which have their own native glass
            // styles). Replaces a hand-rolled dark-mode-only stack of
            // .regularMaterial + tint + stroke.
            .glassEffect(.regular, in: Capsule())
            .scaleEffect(isAnimatingIn ? 1.0 : 0.965)
            .opacity(isAnimatingIn ? 1.0 : 0.0)
            .offset(y: isAnimatingIn ? 0 : 6)
            .modifier(ShakeEffect(animatableData: shakeTrigger))
        }
        .onChange(of: chosenCategoryID) {
            // Picking from the menu shouldn't leave you having to click
            // back into the field to keep typing.
            isInputFocused = true
        }
        .onAppear {
            chosenCategoryID = categoryUI.categoryIDForNewTask(in: store)
            isAnimatingIn = false
            withAnimation(.spring(response: 0.24, dampingFraction: 0.82)) {
                isAnimatingIn = true
            }
            DispatchQueue.main.async {
                isInputFocused = true
            }
            pasteImageMonitor.isActive = true
            pasteImageMonitor.start { image in
                pendingImage = image
            }
        }
        .onDisappear {
            pasteImageMonitor.stop()
            pendingImagePreviewTimer.cancel()
        }
        .onReceive(NotificationCenter.default.publisher(for: .stickyToDoQuickAddFocusRequested)) { _ in
            DispatchQueue.main.async {
                isInputFocused = true
            }
        }
        .onReceive(placeholderTimer) { _ in
            rotatePlaceholderIfNeeded()
        }
    }

    /// Shows where the task will go, and lets you change it. Starts on the
    /// main window's selected tab. A Picker inside a Menu gives the native
    /// checkmarked list; the .glass style matches the category tabs.
    private var categoryPicker: some View {
        Menu {
            Picker("Category", selection: $chosenCategoryID) {
                Text("No category").tag(UUID?.none)
                ForEach(store.categories) { category in
                    Text(category.name).tag(Optional(category.id))
                }
            }
            .pickerStyle(.inline)
            .labelsHidden()
        } label: {
            Text(store.category(for: chosenCategoryID)?.name ?? "No category")
                .lineLimit(1)
        }
        .menuStyle(.button)
        .buttonStyle(.glass)
        .buttonBorderShape(.capsule)
        .controlSize(.large)
        .font(.system(size: 15, weight: .regular))
        .fixedSize(horizontal: true, vertical: false)
        .accessibilityLabel("Category")
        .pointingHandCursorOnHover()
    }

    private var textColor: Color {
        Theme.primaryText
    }

    private var placeholderTextColor: Color {
        Theme.placeholderText
    }

    private var pendingImageIconColor: Color {
        Theme.secondaryText
    }

    private func handlePendingImageHoverChanged(_ hovering: Bool) {
        pendingImagePreviewTimer.cancel()
        if hovering == false {
            withAnimation(.easeOut(duration: 0.12)) {
                showPendingImagePreview = false
            }
            return
        }

        pendingImagePreviewTimer.scheduleShow {
            guard isPendingImageHovered else { return }
            withAnimation(.easeInOut(duration: 0.15)) {
                showPendingImagePreview = true
            }
        }
    }

    private func submit() {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else {
            withAnimation(.spring(response: 0.22, dampingFraction: 0.55)) {
                shakeTrigger += 1
            }
            return
        }
        // Resolved again here in case the category was deleted while the
        // field was open.
        onSubmit(trimmed, store.category(for: chosenCategoryID)?.id, pendingImage)
        text = ""
        pendingImage = nil
        dismissOverlay()
    }

    private func rotatePlaceholderIfNeeded() {
        guard text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        withAnimation(.easeInOut(duration: 0.25)) {
            placeholderIndex = (placeholderIndex + 1) % Layout.rotatingPlaceholders.count
        }
    }

    private func dismissOverlay() {
        guard isClosing == false else { return }
        isClosing = true
        withAnimation(.easeInOut(duration: 0.16)) {
            isAnimatingIn = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
            onClose()
            isClosing = false
        }
    }
}

private enum Layout {
    static let rotatingPlaceholders: [String] = [
        "Add today's task",
        "What do you want to do today?",
        "What's on your mind?",
        "Make today count…"
    ]
}
