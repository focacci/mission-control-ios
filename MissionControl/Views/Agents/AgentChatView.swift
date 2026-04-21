import SwiftUI

/// Dedicated chat screen pushed from Agent Details. Unlike the floating
/// `ChatView`, this is bound to a specific agent — requests route to that
/// agent directly (not the workspace default). The principal toolbar pill
/// uses the standard context button (context kind `.agentChat`).
struct AgentChatView: View {
    let agent: Agent

    @Environment(ChatContextStore.self) private var chatContext

    var body: some View {
        @Bindable var chatContext = chatContext

        ChatConversationView(
            useDefaultAgent: false,
            welcomeMessage: {
                "You're chatting directly with **\(agent.displayName)**. Ask anything."
            },
            floatingChatPresented: $chatContext.showingChat
        )
        .chatContext(.agentChat(
            id: agent.id,
            name: agent.displayName,
            emoji: agent.displayEmoji
        ))
        .chatContextToolbar()
    }
}
