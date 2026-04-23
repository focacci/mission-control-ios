import SwiftUI

/// Dedicated chat screen pushed from Agent Details. Unlike the floating
/// `ChatView`, this is bound to a specific agent — requests route to that
/// agent directly (not the workspace default). The principal toolbar pill
/// uses the standard context button (context kind `.agentChat`).
///
/// When `initialSession` is provided, the view resumes that past thread:
/// messages are fetched once on appear and further sends attach to the
/// same server-side session id.
struct AgentChatView: View {
    let agent: Agent
    let initialSession: ChatSession?

    @Environment(ChatContextStore.self) private var chatContext
    @State private var state = ChatConversationState()
    @State private var isLoadingHistory: Bool
    @State private var hasLoadedInitial = false
    @State private var error: String?

    init(agent: Agent, initialSession: ChatSession? = nil) {
        self.agent = agent
        self.initialSession = initialSession
        _isLoadingHistory = State(initialValue: initialSession != nil)
    }

    private func welcome() -> String {
        "You're chatting directly with **\(agent.displayName)**. Ask anything."
    }

    var body: some View {
        @Bindable var chatContext = chatContext

        Group {
            if isLoadingHistory {
                ProgressView("Loading conversation…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ChatConversationView(
                    useDefaultAgent: false,
                    welcomeMessage: welcome,
                    floatingChatPresented: $chatContext.showingChat,
                    externalState: initialSession != nil ? state : nil
                )
            }
        }
        .chatContext(.agentChat(
            id: agent.id,
            name: agent.displayName,
            emoji: agent.displayEmoji
        ))
        .chatContextToolbar()
        .task { await loadInitialIfNeeded() }
        .errorAlert(message: $error)
    }

    private func loadInitialIfNeeded() async {
        guard let initialSession, !hasLoadedInitial else { return }
        hasLoadedInitial = true
        defer { isLoadingHistory = false }
        do {
            let messages = try await APIClient.shared.chatMessages(
                sessionId: initialSession.id,
                limit: 500
            )
            state.messages = messages.compactMap { msg in
                switch msg.role {
                case .user:
                    return ChatMessage(role: .user, content: msg.content)
                case .assistant:
                    return ChatMessage(
                        role: .agent,
                        content: msg.content,
                        invocationId: msg.invocationId
                    )
                case .system:
                    return nil
                }
            }
            if state.messages.isEmpty {
                state.messages = [ChatMessage(role: .agent, content: welcome())]
            }
            state.sessionId = initialSession.id
        } catch {
            self.error = error.localizedDescription
        }
    }
}
