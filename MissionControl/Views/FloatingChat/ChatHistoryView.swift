import SwiftUI

/// Session picker. Filters are applied on the API side via query params so
/// callers get the right slice: the floating chat sees all sessions for the
/// active agent, while a task/goal detail view sees only sessions scoped to
/// that entity.
struct ChatHistoryView: View {
    let agentId: String?
    let contextType: String?
    let contextId: String?
    let onSelect: (ChatSession, [ChatTranscriptMessage]) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var sessions: [ChatSession] = []
    @State private var isLoading = false
    @State private var loadingSessionId: String?
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Group {
                if isLoading && sessions.isEmpty {
                    ProgressView("Loading history…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if sessions.isEmpty {
                    ContentUnavailableView(
                        "No past chats",
                        systemImage: "bubble.left.and.bubble.right",
                        description: Text("Previous conversations will show up here.")
                    )
                } else {
                    List {
                        ForEach(sessions) { session in
                            Button {
                                Task { await select(session) }
                            } label: {
                                ChatSessionRow(
                                    session: session,
                                    isLoading: loadingSessionId == session.id
                                )
                            }
                            .buttonStyle(.plain)
                        }
                        .onDelete(perform: delete)
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Chat History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .errorAlert(message: $error)
            .task { await load() }
            .refreshable { await load() }
        }
    }

    // MARK: - Actions

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            sessions = try await APIClient.shared.chatSessions(
                agentId: agentId,
                contextType: contextType,
                contextId: contextId,
                limit: 50
            )
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func select(_ session: ChatSession) async {
        loadingSessionId = session.id
        defer { loadingSessionId = nil }
        do {
            let messages = try await APIClient.shared.chatMessages(
                sessionId: session.id,
                limit: 500
            )
            onSelect(session, messages)
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func delete(at offsets: IndexSet) {
        let targets = offsets.map { sessions[$0] }
        sessions.remove(atOffsets: offsets)
        for session in targets {
            Task {
                do {
                    try await APIClient.shared.deleteChatSession(id: session.id)
                } catch {
                    self.error = error.localizedDescription
                    await load()
                }
            }
        }
    }
}

// MARK: - Row

struct ChatSessionRow: View {
    let session: ChatSession
    let isLoading: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "bubble.left.and.text.bubble.right")
                .font(.body)
                .foregroundStyle(.secondary)
                .frame(width: 24, alignment: .center)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 4) {
                Text(session.displayTitle)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: 8) {
                    Text(relativeTime(session.lastMessageAt))
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if let count = session.messageCount {
                        Text("· \(count) messages")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer(minLength: 0)

            if isLoading {
                ProgressView()
            } else {
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }

    private func relativeTime(_ iso: String) -> String {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let date = f.date(from: iso) ?? {
            let f2 = ISO8601DateFormatter()
            return f2.date(from: iso) ?? Date()
        }()
        let rel = RelativeDateTimeFormatter()
        rel.unitsStyle = .short
        return rel.localizedString(for: date, relativeTo: Date())
    }
}
