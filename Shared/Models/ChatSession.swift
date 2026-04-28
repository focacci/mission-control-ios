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

/// One row from `chat_messages`. The UI groups these into `ChatTurn`s —
/// see `ChatConversationView.swift` for the turn model.
///
/// `parts` is the primary structured payload (mirrors `chat_messages.parts`
/// on the server). `content` is the server-derived `partsToText` fallback
/// retained for legacy rows and any caller that hasn't moved to parts.
struct ChatTranscriptMessage: Codable, Identifiable, Hashable {
    let id: String
    let sessionId: String
    let invocationId: String?
    let role: Role
    let content: String
    let parts: [MessagePart]
    let sortOrder: Int
    let createdAt: String

    enum Role: String, Codable {
        case user
        case assistant
        case system
    }

    enum CodingKeys: String, CodingKey {
        case id, sessionId, invocationId, role, content, parts, sortOrder, createdAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decode(String.self, forKey: .id)
        self.sessionId = try c.decode(String.self, forKey: .sessionId)
        self.invocationId = try c.decodeIfPresent(String.self, forKey: .invocationId)
        self.role = try c.decode(Role.self, forKey: .role)
        self.content = try c.decode(String.self, forKey: .content)
        self.parts = try c.decodeIfPresent([MessagePart].self, forKey: .parts) ?? []
        self.sortOrder = try c.decode(Int.self, forKey: .sortOrder)
        self.createdAt = try c.decode(String.self, forKey: .createdAt)
    }

    init(
        id: String,
        sessionId: String,
        invocationId: String?,
        role: Role,
        content: String,
        parts: [MessagePart] = [],
        sortOrder: Int,
        createdAt: String
    ) {
        self.id = id
        self.sessionId = sessionId
        self.invocationId = invocationId
        self.role = role
        self.content = content
        self.parts = parts
        self.sortOrder = sortOrder
        self.createdAt = createdAt
    }
}
