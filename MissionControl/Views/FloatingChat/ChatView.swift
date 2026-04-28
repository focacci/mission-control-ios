import SwiftUI

/// Ephemeral floating chat sheet. Opens from the global bubble button. The
/// leading toolbar carries the lock toggle. The principal slot groups the
/// context pill (selected + pinned counts, expands a panel below the toolbar)
/// alongside two smaller quick-action buttons that add the current page
/// context or clear all selected contexts — kept together because they all
/// operate on the same underlying selection. For the dedicated agent chat
/// page, see `AgentChatView`.
struct ChatView: View {
    @Environment(ChatContextStore.self) private var chatContext
    @State private var isContextPanelExpanded: Bool = false

    var body: some View {
        ChatConversationView(
            useDefaultAgent: true,
            welcomeMessage: { chatContext.welcomeMessage },
            externalState: chatContext.floatingChat
        )
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .top, spacing: 0) { topPanel }
        .toolbar { toolbarContent }
    }

    @ViewBuilder
    private var topPanel: some View {
        if isContextPanelExpanded {
            ChatContextPanel(isExpanded: $isContextPanelExpanded)
                .transition(.move(edge: .top).combined(with: .opacity))
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            ChatLockToolbarButton()
        }
        ToolbarItem(placement: .principal) {
            HStack(spacing: 6) {
                ChatContextPickerToolbarButton(isExpanded: $isContextPanelExpanded)
                addCurrentContextButton
                clearContextsButton
            }
        }
    }

    private var addCurrentContextButton: some View {
        let alreadySelected = chatContext.isSelected(chatContext.pageContext)
        return Button {
            guard !alreadySelected else { return }
            withAnimation(.easeInOut(duration: 0.2)) {
                chatContext.toggleSelected(chatContext.pageContext)
            }
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(alreadySelected ? Color.secondary.opacity(0.5) : Color.secondary)
                .frame(width: 30, height: 30)
                .background(Circle().fill(Color.secondary.opacity(0.12)))
        }
        .disabled(alreadySelected)
        .accessibilityLabel("Add current page to chat context")
    }

    private var clearContextsButton: some View {
        let empty = chatContext.selectedContexts.isEmpty
        return Button {
            guard !empty else { return }
            withAnimation(.easeInOut(duration: 0.2)) {
                chatContext.selectedContexts = []
            }
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(empty ? Color.secondary.opacity(0.5) : Color.secondary)
                .frame(width: 30, height: 30)
                .background(Circle().fill(Color.secondary.opacity(0.12)))
        }
        .disabled(empty)
        .accessibilityLabel("Remove all selected contexts")
    }
}
