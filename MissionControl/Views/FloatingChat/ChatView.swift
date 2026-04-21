import SwiftUI

/// Ephemeral floating chat sheet. Opens from the global bubble button. The
/// center-toolbar context button surfaces the current grounding surface and
/// (eventually) becomes the entry point for pinning and cross-page
/// navigation within context groups. For the dedicated agent chat page,
/// see `AgentChatView`.
struct ChatView: View {
    @Environment(ChatContextStore.self) private var chatContext

    var body: some View {
        ChatConversationView(
            useDefaultAgent: true,
            welcomeMessage: { chatContext.welcomeMessage },
            externalState: chatContext.floatingChat
        )
        .chatContextToolbar(placement: .principal)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                ChatLockToolbarButton()
            }
        }
    }
}
