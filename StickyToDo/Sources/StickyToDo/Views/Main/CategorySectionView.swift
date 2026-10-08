import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct CategorySectionView: View {
    @ObservedObject var categoryUI: CategoryUIState
    @EnvironmentObject private var store: TaskStore
    @Binding var draggingId: UUID?
    let activateWindow: () -> Void
    @FocusState private var focusedCategoryID: UUID?

    var body: some View {
        HStack(spacing: Layout.categoryChipSpacing) {
            categoryChip(
                title: "All",
                isSelected: categoryUI.selectedCategoryID == nil,
                isDropHovered: categoryUI.isAllCategoryDropTargeted
            ) {
                categoryUI.selectedCategoryID = nil
            }
            .onDrop(
                of: [UTType.text],
                delegate: CategoryChipDropDelegate(
                    categoryID: nil,
                    store: store,
                    draggingId: $draggingId,
                    isTargeted: $categoryUI.isAllCategoryDropTargeted
                )
            )

            ForEach(store.categories) { category in
                categoryChipView(for: category)
            }

            if categoryUI.isCategorySectionHovered {
                addCategoryChip
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
        .padding(.horizontal, Layout.sectionHorizontalPadding)
        .padding(.top, Layout.inputToCategorySpacing)
        .frame(maxWidth: .infinity, alignment: .leading)
        .onHover { hovering in
            categoryUI.isCategorySectionHovered = hovering
        }
        // Reports this row's own real rendered height (including its top
        // spacing) so ContentView can size the window from the actual
        // value instead of a guessed constant - the previous guess (46,
        // sized for a since-removed vertical padding) silently went stale
        // when that padding was dropped, leaving a gap at the bottom of
        // the card that had nothing to do with the tabs visually, only
        // with the window being reserved taller than the tabs actually are.
        .background(
            GeometryReader { proxy in
                Color.clear
                    .preference(key: CategorySectionHeightPreferenceKey.self, value: proxy.size.height)
            }
        )
    }

    private var addCategoryChip: some View {
        Button {
            categoryUI.beginCategoryCreation(for: nil)
            activateWindow()
        } label: {
            Image(systemName: "plus")
        }
        .buttonStyle(.glass)
        .buttonBorderShape(.circle)
        .controlSize(.regular)
        .accessibilityLabel("Add category")
        .pointingHandCursorOnHover()
    }

    @ViewBuilder
    private func categoryChipView(for category: TaskCategory) -> some View {
        if categoryUI.editingCategoryID == category.id {
            TextField("", text: $categoryUI.categoryNameDraft)
                .textFieldStyle(.plain)
                .font(.system(size: Layout.chipFontSize))
                .fixedSize(horizontal: true, vertical: false)
                .padding(.horizontal, Layout.renameFieldHorizontalPadding)
                .frame(height: Layout.renameFieldHeight)
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(Theme.separator, lineWidth: 1)
                )
                .focused($focusedCategoryID, equals: category.id)
                .onAppear {
                    focusedCategoryID = category.id
                }
                .onSubmit {
                    categoryUI.commitCategoryRename(categoryID: category.id, store: store)
                }
                .onExitCommand {
                    categoryUI.cancelCategoryRename()
                }
                .onChange(of: focusedCategoryID) { _, focused in
                    guard focused != category.id else { return }
                    if categoryUI.editingCategoryID == category.id {
                        categoryUI.commitCategoryRename(categoryID: category.id, store: store)
                    }
                }
        } else {
            categoryChip(
                title: category.name,
                isSelected: categoryUI.selectedCategoryID == category.id,
                isDropHovered: categoryUI.categoryDropTargetedIDs.contains(category.id)
            ) {
                categoryUI.selectedCategoryID = category.id
            }
            .contextMenu {
                Button("Edit name") {
                    categoryUI.beginCategoryRename(category)
                    activateWindow()
                }
                Button("Delete tab") {
                    categoryUI.deleteCategory(id: category.id, store: store)
                }
            }
            .onDrop(
                of: [UTType.text],
                delegate: CategoryChipDropDelegate(
                    categoryID: category.id,
                    store: store,
                    draggingId: $draggingId,
                    isTargeted: categoryUI.dropTargetBinding(for: category.id)
                )
            )
        }
    }

    /// Native Liquid Glass button styles do all the styling work here: .glass
    /// is the resting pill, .glassProminent is the accent-filled selected one.
    /// Both bring their own backdrop, elevation, label contrast, hit area, and
    /// hover/press feedback - which is why there's no glassEffect(), no manual
    /// fill/stroke/text colors, and no hover-state tracking in this view.
    @ViewBuilder
    private func categoryChip(
        title: String,
        isSelected: Bool,
        isDropHovered: Bool,
        action: @escaping () -> Void
    ) -> some View {
        let isHighlighted = isSelected || isDropHovered
        Group {
            if isHighlighted {
                Button(title, action: action)
                    .buttonStyle(.glassProminent)
                    .tint(Theme.accent)
            } else {
                Button(title, action: action)
                    .buttonStyle(.glass)
            }
        }
        .buttonBorderShape(.capsule)
        .controlSize(.regular)
        .font(.system(size: Layout.chipFontSize))
        .lineLimit(1)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .animation(.easeInOut(duration: 0.12), value: isDropHovered)
        .pointingHandCursorOnHover()
    }
}

private enum Layout {
    static let sectionHorizontalPadding: CGFloat = 16
    static let inputToCategorySpacing: CGFloat = 12
    /// This row used to be a horizontal ScrollView, but ScrollView is backed
    /// by NSClipView, which always hard-clips its content to its own bounds
    /// - there's no SwiftUI opt-out. That was slicing the native
    /// .glass/.glassProminent pills' drop shadow off at the row's top/bottom
    /// edge no matter how much padding was added. A plain HStack has no clip
    /// view, so the shadow renders in full. The trade-off: if the category
    /// count ever grows enough to overflow the card's width, this row will
    /// widen past the card rather than scroll - acceptable while category
    /// counts stay small, but worth revisiting (e.g. a wrapping layout) if
    /// that changes.
    static let chipFontSize: CGFloat = 13
    static let renameFieldHeight: CGFloat = 28
    static let renameFieldHorizontalPadding: CGFloat = 10
    static let categoryChipSpacing: CGFloat = 6
}

/// Bubbles this row's own real rendered height up to ContentView, so the
/// window is sized from the actual value instead of a hand-maintained
/// constant that can silently go stale (see the .background comment above).
struct CategorySectionHeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
