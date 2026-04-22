import SwiftUI

/// Ephemeral floating chat sheet. Opens from the global bubble button. The
/// leading toolbar carries the lock toggle and a context picker that expands
/// into the list of available grounding surfaces. For the dedicated agent
/// chat page, see `AgentChatView`.
struct ChatView: View {
    @Environment(ChatContextStore.self) private var chatContext

    var body: some View {
        ChatConversationView(
            useDefaultAgent: true,
            welcomeMessage: { chatContext.welcomeMessage },
            externalState: chatContext.floatingChat
        )
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                ChatLockToolbarButton()
            }
            ToolbarItem(placement: .topBarLeading) {
                ChatContextPickerToolbarButton()
            }
        }
    }
}
