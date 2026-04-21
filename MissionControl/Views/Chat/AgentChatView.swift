import SwiftUI

/// Dedicated chat screen pushed from Agent Details. Unlike the floating
/// `ChatView`, there is no context chip — the nav bar shows the agent's
/// emoji and name so the user already knows who they're talking to, and
/// requests route to that agent directly (not the workspace default).
struct AgentChatView: View {
    let agent: Agent

    var body: some View {
        ChatConversationView(
            useDefaultAgent: false,
            welcomeMessage: {
                "You're chatting directly with **\(agent.displayName)**. Ask anything."
            }
        )
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                AgentChatTitle(agent: agent)
            }
        }
    }
}

// MARK: - Title View

private struct AgentChatTitle: View {
    let agent: Agent

    var body: some View {
        HStack(spacing: 8) {
            Text(agent.displayEmoji)
                .font(.system(size: 18))
            Text(agent.displayName)
                .font(.headline)
                .lineLimit(1)
        }
        .accessibilityElement(children: .combine)
    }
}
