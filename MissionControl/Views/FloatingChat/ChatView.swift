import SwiftUI

/// Ephemeral floating chat sheet. Opens from the global bubble button. The
/// leading toolbar carries the lock toggle and a context picker that expands
/// into a drop-down panel of context cards below the toolbar. For the
/// dedicated agent chat page, see `AgentChatView`.
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
        .safeAreaInset(edge: .top, spacing: 0) {
            if isContextPanelExpanded {
                ChatContextPanel(isExpanded: $isContextPanelExpanded)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                ChatLockToolbarButton()
            }
            ToolbarItem(placement: .topBarLeading) {
                ChatContextPickerToolbarButton(isExpanded: $isContextPanelExpanded)
            }
        }
    }
}
