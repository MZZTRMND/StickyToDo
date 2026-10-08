import SwiftUI

struct CategoryCreationOverlay: View {
    @ObservedObject var categoryUI: CategoryUIState
    @EnvironmentObject private var store: TaskStore
    @State private var isAddButtonHovered = false
    @FocusState private var isCategoryInputFocused: Bool

    var body: some View {
        ZStack {
            Color.black.opacity(categoryUI.isCategoryModalAnimatingIn ? 0.30 : 0.0)
                .onTapGesture {
                    categoryUI.cancelCategoryCreation()
                }

            HStack(spacing: 8) {
                TextField("New category", text: $categoryUI.newCategoryName)
                    .textFieldStyle(.plain)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(primaryTextColor)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .focused($isCategoryInputFocused)
                    .onSubmit {
                        categoryUI.confirmCategoryCreation(store: store)
                    }
                    .onExitCommand {
                        categoryUI.cancelCategoryCreation()
                    }
                    .padding(.leading, 20)

                Button {
                    categoryUI.confirmCategoryCreation(store: store)
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(primaryTextColor)
                        .frame(width: Layout.addButtonSize, height: Layout.addButtonSize)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Add category")
                .scaleEffect(isAddButtonHovered ? 1.05 : 1.0)
                .animation(.easeInOut(duration: 0.12), value: isAddButtonHovered)
                .onHover { hovering in
                    isAddButtonHovered = hovering
                }
                .padding(.trailing, 6)
            }
            .frame(width: Layout.categoryModalWidth, height: Layout.categoryModalInputHeight)
            // A floating surface, so glassEffect is correct here - unlike on
            // buttons, which have their own native glass styles.
            .glassEffect(.regular, in: Capsule())
            .scaleEffect(categoryUI.isCategoryModalAnimatingIn ? 1.0 : 0.965)
            .opacity(categoryUI.isCategoryModalAnimatingIn ? 1.0 : 0.0)
            .offset(y: categoryUI.isCategoryModalAnimatingIn ? 0 : 6)
            .modifier(ShakeEffect(animatableData: categoryUI.categoryShakeTrigger))
        }
        .onAppear {
            categoryUI.isCategoryModalAnimatingIn = false
            withAnimation(.spring(response: 0.24, dampingFraction: 0.82)) {
                categoryUI.isCategoryModalAnimatingIn = true
            }
            DispatchQueue.main.async {
                isCategoryInputFocused = true
            }
        }
        .onDisappear {
            categoryUI.isCategoryModalAnimatingIn = false
        }
    }

    private var primaryTextColor: Color {
        Theme.primaryText
    }
}

private enum Layout {
    static let categoryModalWidth: CGFloat = 280
    static let categoryModalInputHeight: CGFloat = 44
    static let addButtonSize: CGFloat = 32
}
