import SwiftUI

/// Ephemeral floating chat sheet. Opens from the global bubble button. The
/// leading toolbar carries the lock toggle, an agent picker, and a context
/// picker that each expand into a drop-down panel below the toolbar. For the
/// dedicated agent chat page, see `AgentChatView`.
struct ChatView: View {
    @Environment(ChatContextStore.self) private var chatContext
    @State private var isContextPanelExpanded: Bool = false
    @State private var isAgentPanelExpanded: Bool = false

    var body: some View {
        ChatConversationView(
            useDefaultAgent: true,
            welcomeMessage: { chatContext.welcomeMessage },
            externalState: chatContext.floatingChat
        )
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .top, spacing: 0) { topPanel }
        .toolbar { toolbarContent }
        .onChange(of: isAgentPanelExpanded) { _, newValue in
            if newValue && isContextPanelExpanded {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isContextPanelExpanded = false
                }
            }
        }
        .onChange(of: isContextPanelExpanded) { _, newValue in
            if newValue && isAgentPanelExpanded {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isAgentPanelExpanded = false
                }
            }
        }
    }

    @ViewBuilder
    private var topPanel: some View {
        if isContextPanelExpanded {
            ChatContextPanel(isExpanded: $isContextPanelExpanded)
                .transition(.move(edge: .top).combined(with: .opacity))
        } else if isAgentPanelExpanded {
            ChatAgentPanel(isExpanded: $isAgentPanelExpanded)
                .transition(.move(edge: .top).combined(with: .opacity))
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            ChatLockToolbarButton()
        }
        ToolbarItem(placement: .topBarLeading) {
            ChatAgentPickerToolbarButton(isExpanded: $isAgentPanelExpanded)
        }
        ToolbarItem(placement: .topBarLeading) {
            ChatContextPickerToolbarButton(isExpanded: $isContextPanelExpanded)
        }
    }
}
