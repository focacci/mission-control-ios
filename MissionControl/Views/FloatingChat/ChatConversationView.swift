import SwiftUI

// MARK: - Data

/// One chat exchange: the user's message (optional for the welcome turn) plus
/// the agent's interleaved response segments. A turn maps 1:1 to one server
/// `agent_invocations` row once the invocation id is known.
///
/// Segments are built in two phases:
/// 1. Immediately after `POST /api/chat` returns, `segments` gets a single
///    `.text` entry with the full buffered reply so the user sees output right
///    away.
/// 2. A background `GET /api/invocations/:id` fetch enriches the turn:
///    `segments` is rebuilt by interleaving each assistant `chat_messages`
///    row with its tool calls (matched via `tool_call_log.messageId`), and
///    `tokensIn` / `tokensOut` are populated for the footer.
struct ChatTurn: Identifiable {
    let id = UUID()
    var userContent: String?
    var segments: [TurnSegment] = []
    var invocationId: String?
    var tokensIn: Int?
    var tokensOut: Int?
    var isSending: Bool = false
    var isEnriching: Bool = false
    var hasEnriched: Bool = false
    var errorMessage: String?

    static func welcome(_ text: String) -> ChatTurn {
        ChatTurn(segments: [.text(id: UUID(), content: text)])
    }

    static func user(_ text: String) -> ChatTurn {
        ChatTurn(userContent: text, isSending: true)
    }
}

/// One strip of the agent's response. `.text` comes from a `chat_messages` row;
/// `.toolCall` comes from a `tool_call_log` row (collapsed by default, expand
/// on tap).
enum TurnSegment: Identifiable {
    case text(id: UUID, content: String)
    case toolCall(id: String, call: ToolCallLog)

    var id: String {
        switch self {
        case .text(let id, _):      return "t-\(id.uuidString)"
        case .toolCall(let id, _):  return "c-\(id)"
        }
    }
}

/// Persistent conversation state. Hoisted out of `ChatConversationView` so the
/// floating chat can preserve history across sheet dismissals when locked.
/// AgentChatView and other dedicated chat screens create their own instance
/// scoped to the view's lifetime.
@Observable
final class ChatConversationState {
    var turns: [ChatTurn] = []
    var sessionId: String? = nil
    var inputText: String = ""

    func reset() {
        turns = []
        sessionId = nil
        inputText = ""
    }
}

// MARK: - Chat Request Builder

/// Builds the JSON body shared by both the buffered `POST /api/chat` path and
/// the streaming `POST /api/chat/stream` path. Pure function so both `ChatService`
/// and `ChatStream` use a single source of truth for payload shaping.
enum ChatRequestBuilder {
    static func body(
        message: String,
        context: ChatContextKind,
        sessionId: String?,
        useDefaultAgent: Bool
    ) -> [String: Any] {
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
        case .requirement(let id, let title):
            ctx["id"] = id; ctx["name"] = title
        case .agentAssignment(let id, let title):
            ctx["id"] = id; ctx["name"] = title
        case .agent(let id, let name, let emoji):
            ctx["id"] = id; ctx["name"] = name; ctx["emoji"] = emoji
        case .schedule(let d, let m):
            let f = ISO8601DateFormatter()
            ctx["date"] = f.string(from: d)
            ctx["mode"] = m.rawValue.lowercased()
        case .plans(let s): ctx["section"] = s
        case .health(let s): ctx["section"] = s
        case .faith(let s): ctx["section"] = s
        case .profile(let s): ctx["section"] = s
        case .featureList(let features):
            ctx["features"] = features.joined(separator: ",")
        default: break
        }
        body["context"] = ctx
        return body
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
    ) async throws -> (reply: String, sessionId: String, invocationId: String?) {
        isLoading = true
        defer { isLoading = false }

        let url = URL(string: APIClient.shared.baseURL + "/api/chat")!
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.timeoutInterval = 120

        let body = ChatRequestBuilder.body(
            message: message,
            context: context,
            sessionId: sessionId,
            useDefaultAgent: useDefaultAgent
        )
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            throw APIError.httpError(code)
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        let reply = json["reply"] as? String ?? "No response."
        let sid = json["sessionId"] as? String ?? ""
        let invId = json["invocationId"] as? String
        return (reply, sid, invId)
    }

}

// MARK: - Turn construction helpers

enum ChatTurnBuilder {
    /// Group a flat transcript into turns: each user message starts a new turn;
    /// subsequent assistant messages attach to it and supply the `invocationId`.
    /// Preliminary segments are a text per assistant message — tool rows are
    /// filled in by `enrich(turn:with:)` once the invocation detail loads.
    static func turns(from messages: [ChatTranscriptMessage]) -> [ChatTurn] {
        var out: [ChatTurn] = []
        var current: ChatTurn? = nil

        func flush() {
            if let c = current { out.append(c) }
            current = nil
        }

        for msg in messages {
            switch msg.role {
            case .user:
                flush()
                current = ChatTurn(userContent: msg.content)
            case .assistant:
                if current == nil {
                    current = ChatTurn()
                }
                if current?.invocationId == nil {
                    current?.invocationId = msg.invocationId
                }
                if !msg.content.isEmpty {
                    current?.segments.append(.text(id: UUID(), content: msg.content))
                }
            case .system:
                continue
            }
        }
        flush()
        return out
    }

    /// Replace `turn.segments` with the interleaved message + tool sequence
    /// from a freshly loaded `InvocationDetail`. Tool rows with a `messageId`
    /// attach beneath that message's text; orphan rows (rare — runner covers
    /// this per plan §6.7) fall through to the end of the turn.
    static func enrich(_ turn: ChatTurn, with detail: InvocationDetail) -> ChatTurn {
        var out = turn
        out.invocationId = detail.invocation.id
        out.tokensIn = detail.invocation.tokensIn
        out.tokensOut = detail.invocation.tokensOut
        out.errorMessage = detail.invocation.error
        out.isEnriching = false
        out.hasEnriched = true

        let assistantMessages = detail.messages.filter { $0.role == .assistant }
        var segments: [TurnSegment] = []

        if assistantMessages.isEmpty {
            // Fall back to whatever we had (the buffered reply).
            return out
        }

        for msg in assistantMessages {
            if !msg.content.isEmpty {
                segments.append(.text(id: UUID(), content: msg.content))
            }
            let tools = detail.toolCalls
                .filter { $0.messageId == msg.id }
                .sorted { $0.startedAt < $1.startedAt }
            for t in tools {
                segments.append(.toolCall(id: t.id, call: t))
            }
        }

        let orphans = detail.toolCalls
            .filter { $0.messageId == nil }
            .sorted { $0.startedAt < $1.startedAt }
        for t in orphans {
            segments.append(.toolCall(id: t.id, call: t))
        }

        out.segments = segments
        return out
    }
}

// MARK: - Streaming reducer

/// Folds one streaming `AgentEvent` into a `ChatTurn`. Pure mutation — no
/// async, no side effects. Tool events are intentionally ignored in this
/// step; the post-stream `enrichTurn(...)` call splices tool rows in via the
/// existing buffered-path logic. Step 4 of the POC plan extends `.toolUse` /
/// `.toolResult` to render inline.
enum ChatTurnReducer {
    static func apply(_ event: AgentEvent, to turn: inout ChatTurn) {
        switch event {
        case .sessionStarted(_, let invocationId, _):
            turn.invocationId = invocationId

        case .textDelta(let text):
            if case .text(let id, let existing) = turn.segments.last {
                turn.segments[turn.segments.count - 1] = .text(id: id, content: existing + text)
            } else {
                turn.segments.append(.text(id: UUID(), content: text))
            }

        case .messageComplete:
            // No-op for step 2 — text segment already carries the latest content.
            break

        case .done(let tokensIn, let tokensOut):
            turn.tokensIn = tokensIn
            turn.tokensOut = tokensOut
            turn.isSending = false

        case .error(let message, _, let fatal):
            turn.errorMessage = message
            if fatal { turn.isSending = false }

        case .toolUse, .toolResult, .ping:
            break
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

    @State private var localState = ChatConversationState()
    @State private var showingHistory = false
    @State private var isStartingNewChat = false
    @State private var historyError: String?
    @State private var activeTurnTask: Task<Void, Never>? = nil
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
        turnList
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
                if state.turns.isEmpty {
                    state.turns = [.welcome(welcomeMessage())]
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
        state.turns = [.welcome(welcomeMessage())]
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
            state.turns = [.welcome(welcomeMessage())]
            state.inputText = ""
            state.sessionId = session.id
        } catch {
            historyError = error.localizedDescription
        }
    }

    /// Replace the in-memory thread with a previously persisted session.
    /// Groups flat transcript messages into turns, then enriches each one
    /// that has an `invocationId` with tool calls + token counts.
    private func loadSession(_ session: ChatSession, messages: [ChatTranscriptMessage]) {
        var turns = ChatTurnBuilder.turns(from: messages)
        if turns.isEmpty {
            turns = [.welcome(welcomeMessage())]
        }
        state.turns = turns
        state.inputText = ""
        state.sessionId = session.id

        // Enrich each turn with tool calls + tokens in the background. One
        // fetch per invocation; fire-and-forget so the list renders first.
        for turn in turns {
            if let invId = turn.invocationId {
                Task { await enrichTurn(turnId: turn.id, invocationId: invId) }
            }
        }
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

    // MARK: - Turn List

    private var turnList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 20) {
                    ForEach(state.turns) { turn in
                        TurnView(turn: turn)
                            .id(turn.id)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: state.turns.count) {
                if let last = state.turns.last {
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

            Button {
                if isAwaitingResponse { stopMessage() } else { sendMessage() }
            } label: {
                Image(systemName: isAwaitingResponse ? "stop.fill" : "arrow.up")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(buttonIsActive ? Color.white : Color.secondary)
                    .frame(width: 44, height: 44)
                    .modifier(LiquidGlassSendButtonBackground(isEnabled: buttonIsActive))
            }
            .disabled(!buttonIsActive)
            .animation(.easeInOut(duration: 0.15), value: state.inputText.isEmpty)
            .animation(.easeInOut(duration: 0.15), value: isAwaitingResponse)
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

    private var activeSendingTurn: ChatTurn? {
        state.turns.last(where: { $0.isSending })
    }

    private var isAwaitingResponse: Bool {
        activeSendingTurn != nil
    }

    private var canSend: Bool {
        !state.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !isAwaitingResponse
    }

    /// The button is interactable (and renders in its filled style) whenever
    /// it has something to do — either send a fresh message or stop the
    /// in-flight turn.
    private var buttonIsActive: Bool {
        canSend || isAwaitingResponse
    }

    // MARK: - Send flow

    private func sendMessage() {
        let text = state.inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        state.inputText = ""

        let turn = ChatTurn.user(text)
        state.turns.append(turn)

        activeTurnTask = Task {
            await runTurn(turnId: turn.id, text: text)
            activeTurnTask = nil
        }
    }

    /// Stop the in-flight turn. Cancels the local Task (which aborts the
    /// URLSession request for both the buffered and streaming paths) and,
    /// if we already know the invocation id, asks the server to abort the
    /// gateway run so it doesn't keep burning tokens after we've moved on.
    private func stopMessage() {
        guard let turn = activeSendingTurn else { return }
        let turnId = turn.id
        let invocationId = turn.invocationId

        activeTurnTask?.cancel()
        activeTurnTask = nil

        if let invocationId {
            Task { try? await APIClient.shared.cancelInvocation(id: invocationId) }
        }

        updateTurn(turnId) { t in
            t.isSending = false
            if t.errorMessage == nil {
                t.errorMessage = "Cancelled"
            }
        }
    }

    private func runTurn(turnId: UUID, text: String) async {
        if FeatureFlags.useStreamingChat {
            await runTurnStreaming(turnId: turnId, text: text)
        } else {
            await runTurnBuffered(turnId: turnId, text: text)
        }
    }

    private func runTurnBuffered(turnId: UUID, text: String) async {
        do {
            let result = try await chatService.send(
                message: text,
                context: activeContext,
                sessionId: state.sessionId,
                useDefaultAgent: useDefaultAgent
            )
            state.sessionId = result.sessionId
            updateTurn(turnId) { t in
                t.isSending = false
                t.invocationId = result.invocationId
                // Seed a single text segment so the buffered reply shows
                // immediately; the enrich step rebuilds it with tool rows.
                if !result.reply.isEmpty {
                    t.segments = [.text(id: UUID(), content: result.reply)]
                }
            }

            if let invId = result.invocationId {
                await enrichTurn(turnId: turnId, invocationId: invId)
            }
        } catch {
            updateTurn(turnId) { t in
                t.isSending = false
                t.errorMessage = error.localizedDescription
            }
        }
    }

    private func runTurnStreaming(turnId: UUID, text: String) async {
        let stream = ChatStream()
        do {
            let result = try await stream.run(
                message: text,
                context: activeContext,
                sessionId: state.sessionId,
                useDefaultAgent: useDefaultAgent
            ) { event in
                updateTurn(turnId) { t in
                    ChatTurnReducer.apply(event, to: &t)
                }
            }
            if let sid = result.sessionId {
                state.sessionId = sid
            }
            // Post-stream enrich splices tool rows + token counts via the
            // existing buffered-path code. Step 4 extends the reducer to
            // render tool events inline; until then this keeps the tool UI
            // from regressing.
            if let invId = result.invocationId {
                await enrichTurn(turnId: turnId, invocationId: invId)
            }
        } catch {
            updateTurn(turnId) { t in
                t.isSending = false
                t.errorMessage = error.localizedDescription
            }
        }
    }

    /// Fetch the invocation detail and splice tool calls + token counts into
    /// the matching turn. Best-effort: if it fails, the user still has the
    /// buffered reply — we just skip tool rows and the token footer.
    private func enrichTurn(turnId: UUID, invocationId: String) async {
        updateTurn(turnId) { $0.isEnriching = true }
        do {
            let detail = try await APIClient.shared.invocation(id: invocationId)
            updateTurn(turnId) { t in
                t = ChatTurnBuilder.enrich(t, with: detail)
            }
        } catch {
            updateTurn(turnId) { $0.isEnriching = false }
        }
    }

    private func updateTurn(_ id: UUID, _ mutate: (inout ChatTurn) -> Void) {
        guard let idx = state.turns.firstIndex(where: { $0.id == id }) else { return }
        var t = state.turns[idx]
        mutate(&t)
        state.turns[idx] = t
    }
}

// MARK: - Turn rendering

struct TurnView: View {
    let turn: ChatTurn

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let user = turn.userContent {
                HStack {
                    Spacer(minLength: 52)
                    UserBubble(text: user)
                }
            }

            if turn.isSending && turn.segments.isEmpty {
                ThinkingBubble()
            }

            ForEach(turn.segments) { segment in
                switch segment {
                case .text(_, let content):
                    AgentTextBubble(content: content, isError: false)
                case .toolCall(_, let call):
                    ToolStepRow(call: call)
                }
            }

            if let err = turn.errorMessage {
                AgentTextBubble(content: "⚠️ \(err)", isError: true)
            }

            TurnFooter(turn: turn)
        }
    }
}

private struct UserBubble: View {
    let text: String
    var body: some View {
        Text(LocalizedStringKey(text))
            .font(.body)
            .foregroundStyle(.white)
            .multilineTextAlignment(.leading)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color.blue, in: RoundedRectangle(cornerRadius: 18))
    }
}

private struct AgentTextBubble: View {
    let content: String
    let isError: Bool
    var body: some View {
        Text(LocalizedStringKey(content))
            .font(.body)
            .foregroundStyle(isError ? Color.red : .primary)
            .multilineTextAlignment(.leading)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct ThinkingBubble: View {
    @State private var phase = 0
    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<3) { i in
                Circle()
                    .fill(Color.secondary)
                    .frame(width: 6, height: 6)
                    .opacity(phase == i ? 1.0 : 0.3)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(.regularMaterial, in: Capsule())
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 280_000_000)
                withAnimation(.easeInOut(duration: 0.25)) {
                    phase = (phase + 1) % 3
                }
            }
        }
    }
}

/// Collapsed inline tool step. Quiet by default — just the tool name + the
/// server-provided one-line `summary`. Tap to expand and see the raw JSON
/// input/output (same shape as the debug view).
private struct ToolStepRow: View {
    let call: ToolCallLog
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button {
                withAnimation(.easeInOut(duration: 0.15)) { isExpanded.toggle() }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: call.isError
                        ? "exclamationmark.triangle.fill"
                        : "wrench.and.screwdriver")
                        .font(.caption)
                        .foregroundStyle(call.isError ? .red : .secondary)
                    Text(call.toolName)
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(call.isError ? .red : .primary)
                    if let summary = call.summary, !summary.isEmpty {
                        Text("·").foregroundStyle(.tertiary)
                        Text(summary)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                    Spacer(minLength: 0)
                    if let ms = call.durationMs {
                        Text("\(ms)ms")
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(.tertiary)
                    }
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                if !call.input.isEmpty {
                    ToolPayloadBlock(label: "input", content: call.input)
                }
                if let output = call.output, !output.isEmpty {
                    ToolPayloadBlock(label: "output", content: output)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
    }
}

private struct ToolPayloadBlock: View {
    let label: String
    let content: String
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(content)
                .font(.caption2.monospaced())
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// Footer beneath an agent turn: optional token count + "View run →" link
/// that pushes `InvocationDetailView`. Hidden entirely for turns with no
/// invocation (e.g. the welcome greeting or an error that never reached the
/// server).
private struct TurnFooter: View {
    let turn: ChatTurn

    var body: some View {
        guard let invocationId = turn.invocationId else {
            return AnyView(EmptyView())
        }

        let totalTokens: Int? = {
            guard let i = turn.tokensIn, let o = turn.tokensOut else { return nil }
            let sum = i + o
            return sum > 0 ? sum : nil
        }()

        return AnyView(
            NavigationLink {
                InvocationDetailView(invocationId: invocationId)
            } label: {
                HStack(spacing: 6) {
                    if let total = totalTokens {
                        Text("\(total) tokens")
                        Text("·").foregroundStyle(.tertiary)
                    } else if turn.isEnriching {
                        ProgressView().controlSize(.mini)
                    }
                    Text("View run")
                    Image(systemName: "arrow.up.right")
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
                .padding(.leading, 14)
            }
            .buttonStyle(.plain)
        )
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
