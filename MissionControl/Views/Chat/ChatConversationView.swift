import SwiftUI

// MARK: - Data

struct ChatMessage: Identifiable {
    let id = UUID()
    let role: Role
    let content: String

    enum Role { case user, agent }
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

        var ctx: [String: String] = ["type": contextTypeString(context)]
        switch context {
        case .goal(let id, let emoji, let name):
            ctx["id"] = id; ctx["emoji"] = emoji; ctx["name"] = name
        case .initiative(let id, let emoji, let name):
            ctx["id"] = id; ctx["emoji"] = emoji; ctx["name"] = name
        case .task(let id, let name):
            ctx["id"] = id; ctx["name"] = name
        case .agent(let id, let name, let emoji):
            ctx["id"] = id; ctx["name"] = name; ctx["emoji"] = emoji
        case .schedule(let d):
            let f = ISO8601DateFormatter(); ctx["date"] = f.string(from: d)
        case .dashboard(let s): ctx["section"] = s
        case .health(let s): ctx["section"] = s
        case .faith(let s): ctx["section"] = s
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

    private func contextTypeString(_ kind: ChatContextKind) -> String {
        switch kind {
        case .app: return "app"
        case .home: return "home"
        case .agents: return "agents"
        case .agent: return "agent"
        case .dashboard: return "dashboard"
        case .goal: return "goal"
        case .initiative: return "initiative"
        case .task: return "task"
        case .schedule: return "schedule"
        case .health: return "health"
        case .faith: return "faith"
        }
    }
}

// MARK: - Shared Chat Conversation

/// Chat bubbles + input bar. Owns its own message/send state and contributes
/// a "new chat" toolbar button to the enclosing navigation bar. Callers wrap
/// this with their own header (context chip, agent hero, etc.).
struct ChatConversationView: View {
    @Environment(ChatContextStore.self) private var chatContext
    @StateObject private var chatService = ChatService()

    @State private var messages: [ChatMessage] = []
    @State private var inputText = ""
    @State private var sessionId: String?
    @FocusState private var isInputFocused: Bool

    /// When `true`, requests route to the workspace's default agent regardless
    /// of the current context. Pass `false` to route to the context's agent.
    let useDefaultAgent: Bool

    /// Greeting shown when the conversation resets. Evaluated lazily so it
    /// can read live state (context, agent name, etc.).
    let welcomeMessage: () -> String

    init(
        useDefaultAgent: Bool,
        welcomeMessage: @escaping () -> String
    ) {
        self.useDefaultAgent = useDefaultAgent
        self.welcomeMessage = welcomeMessage
    }

    var body: some View {
        messageList
            .safeAreaInset(edge: .bottom, spacing: 0) {
                inputBarContainer
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: resetChat) {
                        Image(systemName: "square.and.pencil")
                    }
                    .accessibilityLabel("New chat")
                }
            }
            .onAppear {
                if messages.isEmpty {
                    messages = [ChatMessage(role: .agent, content: welcomeMessage())]
                }
            }
            .onChange(of: chatContext.context) {
                resetChat()
            }
    }

    private func resetChat() {
        messages = [ChatMessage(role: .agent, content: welcomeMessage())]
        inputText = ""
        sessionId = nil
    }

    // MARK: - Message List

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    ForEach(messages) { message in
                        MessageBubble(message: message)
                            .id(message.id)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: messages.count) {
                if let last = messages.last {
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
        HStack(alignment: .bottom, spacing: 10) {
            TextField("Ask anything…", text: $inputText, axis: .vertical)
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
            .animation(.easeInOut(duration: 0.15), value: inputText.isEmpty)
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
        !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !chatService.isLoading
    }

    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        inputText = ""
        messages.append(ChatMessage(role: .user, content: text))

        Task {
            do {
                let result = try await chatService.send(
                    message: text,
                    context: chatContext.context,
                    sessionId: sessionId,
                    useDefaultAgent: useDefaultAgent
                )
                sessionId = result.sessionId
                messages.append(ChatMessage(role: .agent, content: result.reply))
            } catch {
                messages.append(ChatMessage(
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
