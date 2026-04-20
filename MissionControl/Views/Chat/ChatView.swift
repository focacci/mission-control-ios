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
        sessionId: String?
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

        var ctx: [String: String] = ["type": contextTypeString(context)]
        switch context {
        case .goal(let id, let emoji, let name):
            ctx["id"] = id; ctx["emoji"] = emoji; ctx["name"] = name
        case .initiative(let id, let emoji, let name):
            ctx["id"] = id; ctx["emoji"] = emoji; ctx["name"] = name
        case .task(let id, let name):
            ctx["id"] = id; ctx["name"] = name
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

// MARK: - Chat Sheet

struct ChatView: View {
    @Environment(ChatContextStore.self) private var chatContext
    @StateObject private var chatService = ChatService()

    @State private var messages: [ChatMessage] = []
    @State private var inputText = ""
    @State private var sessionId: String?
    @FocusState private var isInputFocused: Bool

    var floatingChatPresented: Binding<Bool>? = nil

    var body: some View {
        VStack(spacing: 0) {
            contextChip
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 12)

            Divider()

            messageList

            Divider()

            inputBar
        }
        .navigationTitle("Agents")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: resetChat) {
                    Image(systemName: "square.and.pencil")
                }
            }
        }
        .onAppear {
            messages = [ChatMessage(role: .agent, content: chatContext.welcomeMessage)]
        }
        .onChange(of: chatContext.context) {
            messages = [ChatMessage(role: .agent, content: chatContext.welcomeMessage)]
            inputText = ""
            sessionId = nil
        }
    }

    private func resetChat() {
        messages = [ChatMessage(role: .agent, content: chatContext.welcomeMessage)]
        inputText = ""
        sessionId = nil
    }

    // MARK: - Context Chip

    private var contextChip: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(.blue.opacity(0.12))
                    .frame(width: 36, height: 36)

                Image(systemName: chatContext.displayIcon)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.blue)

            }

            VStack(alignment: .leading, spacing: 2) {
                Text(chatContext.contextTypeName.uppercased())
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.blue.opacity(0.7))
                    .tracking(0.8)

                Text(chatContext.displayLabel)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
            }

            Spacer()

            if chatService.isLoading {
                ProgressView()
                    .scaleEffect(0.8)
                    .padding(6)
            } else {
                Label("context", systemImage: "scope")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .labelStyle(.iconOnly)
                    .padding(6)
                    .background(.quaternary, in: Circle())
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.blue.opacity(0.06), in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(.blue.opacity(0.18), lineWidth: 1)
        )
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
            .floatingChatButton(isPresented: floatingChatPresented)
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

    private var inputBar: some View {
        HStack(alignment: .bottom, spacing: 10) {
            TextField("Ask anything…", text: $inputText, axis: .vertical)
                .lineLimit(1...5)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22))
                .focused($isInputFocused)

            Button(action: sendMessage) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(
                        inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || chatService.isLoading
                            ? Color.secondary : .blue
                    )
            }
            .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || chatService.isLoading)
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
                    sessionId: sessionId
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
