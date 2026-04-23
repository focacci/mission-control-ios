import SwiftUI

// MARK: - Data

struct ChatMessage: Identifiable {
    let id = UUID()
    let role: Role
    let content: String

    enum Role { case user, agent }
}

/// Persistent conversation state. Hoisted out of `ChatConversationView` so the
/// floating chat can preserve history across sheet dismissals when locked.
/// AgentChatView and other dedicated chat screens create their own instance
/// scoped to the view's lifetime.
@Observable
final class ChatConversationState {
    var messages: [ChatMessage] = []
    var sessionId: String? = nil
    var inputText: String = ""

    func reset() {
        messages = []
        sessionId = nil
        inputText = ""
    }
}

// MARK: - Chat Service

@MainActor
final class ChatService: ObservableObject {
    @Published var isLoading = false

    func send(
        message: String,
        context: ChatContextKind,
        sessionId: String?,
        useDefaultAgent: Bool
    ) async throws -> (reply: String, sessionId: String) {
        isLoading = true
        defer { isLoading = false }

        let url = URL(string: APIClient.shared.baseURL + "/api/chat")!
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.timeoutInterval = 120

        var body: [String: Any] = ["message": message]
        if let sid = sessionId { body["sessionId"] = sid }
        if !useDefaultAgent, let aid = context.agentId { body["agentId"] = aid }

        var ctx: [String: String] = ["type": context.contextType]
        switch context {
        case .goal(let id, let emoji, let name):
            ctx["id"] = id; ctx["emoji"] = emoji; ctx["name"] = name
        case .initiative(let id, let emoji, let name):
            ctx["id"] = id; ctx["emoji"] = emoji; ctx["name"] = name
        case .task(let id, let name):
            ctx["id"] = id; ctx["name"] = name
        case .agent(let id, let name, let emoji):
            ctx["id"] = id; ctx["name"] = name; ctx["emoji"] = emoji
        case .schedule(let d, let m):
            let f = ISO8601DateFormatter()
            ctx["date"] = f.string(from: d)
            ctx["mode"] = m.rawValue.lowercased()
        case .plans(let s): ctx["section"] = s
        case .health(let s): ctx["section"] = s
        case .faith(let s): ctx["section"] = s
        case .featureList(let features):
            ctx["features"] = features.joined(separator: ",")
        default: break
        }
        body["context"] = ctx

        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            throw APIError.httpError(code)
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        let reply = json["reply"] as? String ?? "No response."
        let sid = json["sessionId"] as? String ?? ""
        return (reply, sid)
    }

}

// MARK: - Shared Chat Conversation

/// Chat bubbles + input bar. Owns its own message/send state and contributes
/// a "new chat" toolbar button to the enclosing navigation bar. Callers wrap
/// this with their own header (context chip, agent hero, etc.).
struct ChatConversationView: View {
    @Environment(ChatContextStore.self) private var chatContext
    @StateObject private var chatService = ChatService()

    @State private var localState = ChatConversationState()
    @State private var showingHistory = false
    @State private var isStartingNewChat = false
    @State private var historyError: String?
    @FocusState private var isInputFocused: Bool

    /// When `true`, requests route to the workspace's default agent regardless
    /// of the current context. Pass `false` to route to the context's agent.
    let useDefaultAgent: Bool

    /// Greeting shown when the conversation resets. Evaluated lazily so it
    /// can read live state (context, agent name, etc.).
    let welcomeMessage: () -> String

    /// Optional binding for the ephemeral chat bubble. When non-nil the
    /// floating button is layered above the input bar so it stays reachable
    /// from dedicated chat screens (e.g. AgentChatView).
    let floatingChatPresented: Binding<Bool>?

    /// External conversation state. When provided (e.g. the floating chat
    /// sheet passing the store-owned instance), history survives view
    /// teardown. Otherwise falls back to the view-local state.
    private let externalState: ChatConversationState?

    private var state: ChatConversationState { externalState ?? localState }

    init(
        useDefaultAgent: Bool,
        welcomeMessage: @escaping () -> String,
        floatingChatPresented: Binding<Bool>? = nil,
        externalState: ChatConversationState? = nil
    ) {
        self.useDefaultAgent = useDefaultAgent
        self.welcomeMessage = welcomeMessage
        self.floatingChatPresented = floatingChatPresented
        self.externalState = externalState
    }

    var body: some View {
        messageList
            .floatingChatButton(isPresented: floatingChatPresented)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                inputBarContainer
            }
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            Task { await startNewChat() }
                        } label: {
                            Label("New chat", systemImage: "square.and.pencil")
                        }
                        Button {
                            showingHistory = true
                        } label: {
                            Label("History", systemImage: "clock.arrow.circlepath")
                        }
                    } label: {
                        if isStartingNewChat {
                            ProgressView()
                        } else {
                            Image(systemName: "ellipsis")
                        }
                    }
                }
            }
            .sheet(isPresented: $showingHistory) {
                ChatHistoryView(
                    agentId: historyAgentId,
                    contextType: historyContextType,
                    contextId: historyContextId
                ) { session, messages in
                    loadSession(session, messages: messages)
                }
            }
            .onAppear {
                if state.messages.isEmpty {
                    state.messages = [ChatMessage(role: .agent, content: welcomeMessage())]
                }
            }
            .onChange(of: activeContext) {
                // Skip when locked so the pinned conversation survives context
                // changes (e.g. user locks chat, closes sheet, navigates tabs).
                if !chatContext.isLocked {
                    resetLocalState()
                }
            }
            .errorAlert(message: $historyError)
    }

    /// Context used for routing, send payloads, and history scoping.
    ///
    /// - Floating chat (`useDefaultAgent == true`): the user's explicit
    ///   grounding selection; falls back to `.app` when nothing is selected
    ///   so the chat runs ungrounded against the default agent.
    /// - Agent-bound chat (`useDefaultAgent == false`): always the current
    ///   page context, since the enclosing screen (`AgentChatView`) sets it
    ///   to `.agentChat(...)` and routes through that agent unconditionally.
    private var activeContext: ChatContextKind {
        if useDefaultAgent {
            return chatContext.primarySelectedContext ?? .app
        } else {
            return chatContext.pageContext
        }
    }

    /// Clears the in-memory thread without touching the server. Used when the
    /// underlying chat context changes — the previous session is already
    /// persisted on the API side.
    private func resetLocalState() {
        state.messages = [ChatMessage(role: .agent, content: welcomeMessage())]
        state.inputText = ""
        state.sessionId = nil
    }

    /// "New chat" entry point. Calls `POST /api/chat/sessions` so the next
    /// send attaches to a fresh thread instead of being resumed by
    /// `findOrCreateSession` on the server.
    private func startNewChat() async {
        isStartingNewChat = true
        defer { isStartingNewChat = false }
        do {
            let session = try await APIClient.shared.createChatSession(
                agentId: resolvedAgentId,
                contextType: activeContext.contextType,
                contextId: activeContext.contextId
            )
            state.messages = [ChatMessage(role: .agent, content: welcomeMessage())]
            state.inputText = ""
            state.sessionId = session.id
        } catch {
            historyError = error.localizedDescription
        }
    }

    /// Replace the in-memory thread with a previously persisted session.
    private func loadSession(_ session: ChatSession, messages: [ChatTranscriptMessage]) {
        state.messages = messages.compactMap { msg in
            switch msg.role {
            case .user:      return ChatMessage(role: .user, content: msg.content)
            case .assistant: return ChatMessage(role: .agent, content: msg.content)
            case .system:    return nil
            }
        }
        if state.messages.isEmpty {
            state.messages = [ChatMessage(role: .agent, content: welcomeMessage())]
        }
        state.inputText = ""
        state.sessionId = session.id
    }

    // MARK: - History filter scope

    /// When using the default agent the floating chat roams across contexts;
    /// pinning history to just the current `agentId` would hide most threads.
    /// When bound to a specific agent (e.g. AgentChatView), scope to that
    /// agent's conversations.
    private var historyAgentId: String? {
        useDefaultAgent ? nil : activeContext.agentId
    }

    private var historyContextType: String? { nil }
    private var historyContextId: String? { nil }

    private var resolvedAgentId: String {
        if !useDefaultAgent, let id = activeContext.agentId {
            return id
        }
        return "intella"
    }

    // MARK: - Message List

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    ForEach(state.messages) { message in
                        MessageBubble(message: message)
                            .id(message.id)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: state.messages.count) {
                if let last = state.messages.last {
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
        }
    }

    // MARK: - Input Bar

    @ViewBuilder
    private var inputBarContainer: some View {
        if #available(iOS 26.0, *) {
            GlassEffectContainer(spacing: 10) {
                inputBar
            }
        } else {
            VStack(spacing: 0) {
                Divider()
                inputBar
            }
            .background(.bar)
        }
    }

    private var inputBar: some View {
        @Bindable var boundState = state

        return HStack(alignment: .bottom, spacing: 10) {
            TextField("Ask anything…", text: $boundState.inputText, axis: .vertical)
                .lineLimit(1...5)
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
                .modifier(LiquidGlassInputBackground())
                .focused($isInputFocused)
                .submitLabel(.send)

            Button(action: sendMessage) {
                Image(systemName: "arrow.up")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(canSend ? Color.white : Color.secondary)
                    .frame(width: 44, height: 44)
                    .modifier(LiquidGlassSendButtonBackground(isEnabled: canSend))
            }
            .disabled(!canSend)
            .animation(.easeInOut(duration: 0.15), value: state.inputText.isEmpty)
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .simultaneousGesture(
            DragGesture(minimumDistance: 20, coordinateSpace: .local)
                .onChanged { value in
                    if value.translation.height > 0 {
                        isInputFocused = false
                    }
                }
        )
    }

    private var canSend: Bool {
        !state.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !chatService.isLoading
    }

    private func sendMessage() {
        let text = state.inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        state.inputText = ""
        state.messages.append(ChatMessage(role: .user, content: text))

        Task {
            do {
                let result = try await chatService.send(
                    message: text,
                    context: activeContext,
                    sessionId: state.sessionId,
                    useDefaultAgent: useDefaultAgent
                )
                state.sessionId = result.sessionId
                state.messages.append(ChatMessage(role: .agent, content: result.reply))
            } catch {
                state.messages.append(ChatMessage(
                    role: .agent,
                    content: "⚠️ Error: \(error.localizedDescription)"
                ))
            }
        }
    }
}

// MARK: - Liquid Glass Modifiers

private struct LiquidGlassInputBackground: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.glassEffect(.regular.interactive(), in: .capsule)
        } else {
            content.background(.regularMaterial, in: Capsule())
        }
    }
}

private struct LiquidGlassSendButtonBackground: ViewModifier {
    let isEnabled: Bool

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.glassEffect(
                isEnabled ? .regular.tint(.blue).interactive() : .regular.interactive(),
                in: .circle
            )
        } else {
            content.background(
                isEnabled ? AnyShapeStyle(Color.blue) : AnyShapeStyle(Material.regularMaterial),
                in: Circle()
            )
        }
    }
}

// MARK: - Message Bubble

struct MessageBubble: View {
    let message: ChatMessage

    var isUser: Bool { message.role == .user }

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if isUser {
                Spacer(minLength: 52)
            }

            Text(LocalizedStringKey(message.content))
                .font(.body)
                .foregroundStyle(isUser ? .white : .primary)
                .multilineTextAlignment(.leading)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    isUser
                        ? AnyShapeStyle(Color.blue)
                        : AnyShapeStyle(Material.regularMaterial),
                    in: RoundedRectangle(cornerRadius: 18)
                )
                .frame(maxWidth: .infinity, alignment: isUser ? .trailing : .leading)

            if isUser {
                Spacer(minLength: 0)
                    .frame(width: 0)
            }
        }
    }
}
