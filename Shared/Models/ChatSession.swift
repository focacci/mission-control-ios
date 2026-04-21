import Foundation

/// Server-persisted chat thread. One row per (agent × optional context) group;
/// messages live in a separate table and are paginated by `sortOrder`.
struct ChatSession: Codable, Identifiable, Hashable {
    let id: String
    let agentId: String
    let contextType: String?
    let contextId: String?
    let title: String?
    let createdAt: String
    let lastMessageAt: String

    /// Present only on `GET /api/chat/sessions/:id` (the detail endpoint).
    let messageCount: Int?

    var displayTitle: String {
        if let t = title, !t.isEmpty { return t }
        return "Untitled chat"
    }
}

/// One row from `chat_messages`. Named to avoid colliding with the local
/// UI struct `ChatMessage` used by `ChatConversationView`.
struct ChatTranscriptMessage: Codable, Identifiable, Hashable {
    let id: String
    let sessionId: String
    let invocationId: String?
    let role: Role
    let content: String
    let sortOrder: Int
    let createdAt: String

    enum Role: String, Codable {
        case user
        case assistant
        case system
    }
}
