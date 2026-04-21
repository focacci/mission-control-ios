import SwiftUI

/// Card listing past chats scoped to a specific entity. Drop into a task,
/// goal, initiative, or agent detail view — it filters the session list
/// on the server side and hides itself when there are no sessions yet.
///
/// Pass one of:
/// - `contextType` + `contextId` for task/goal/initiative scoped history
/// - `agentId` alone for "everything this agent has ever talked about"
struct ContextChatHistorySection: View {
    var agentId: String? = nil
    var contextType: String? = nil
    var contextId: String? = nil
    var limit: Int = 5

    init(
        contextType: String,
        contextId: String,
        limit: Int = 5
    ) {
        self.contextType = contextType
        self.contextId = contextId
        self.limit = limit
    }

    init(agentId: String, limit: Int = 5) {
        self.agentId = agentId
        self.limit = limit
    }

    @State private var sessions: [ChatSession] = []
    @State private var isLoading = true
    @State private var error: String?

    var body: some View {
        Group {
            if isLoading {
                HStack {
                    ProgressView()
                    Text("Loading chat history…")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
            } else if sessions.isEmpty {
                EmptyView()
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Label("Past Chats", systemImage: "bubble.left.and.text.bubble.right")
                            .font(.headline)
                        Spacer()
                        Text("\(sessions.count)")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }

                    ForEach(sessions) { session in
                        NavigationLink {
                            ChatTranscriptView(session: session)
                        } label: {
                            ChatSessionRow(session: session, isLoading: false)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button(role: .destructive) {
                                Task { await delete(session) }
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                        if session.id != sessions.last?.id {
                            Divider()
                        }
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
            }
        }
        .task { await load() }
        .errorAlert(message: $error)
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            sessions = try await APIClient.shared.chatSessions(
                agentId: agentId,
                contextType: contextType,
                contextId: contextId,
                limit: limit
            )
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func delete(_ session: ChatSession) async {
        do {
            try await APIClient.shared.deleteChatSession(id: session.id)
            sessions.removeAll { $0.id == session.id }
        } catch {
            self.error = error.localizedDescription
        }
    }
}
