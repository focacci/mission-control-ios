import Foundation

/// One execution of an agent (chat turn, scheduled slot-start, brief, or
/// manual trigger). Source of truth for "what did the agent actually do."
struct AgentInvocation: Codable, Identifiable, Hashable {
    let id: String
    let trigger: Trigger
    let triggerRefId: String?
    let agentId: String
    let sessionId: String
    let status: Status
    let model: String
    let startedAt: String
    let endedAt: String?
    let error: String?
    let tokensIn: Int
    let tokensOut: Int

    enum Trigger: String, Codable, CaseIterable {
        case slotStart = "slot_start"
        case brief
        case userChat = "user_chat"
        case manual
    }

    enum Status: String, Codable, CaseIterable {
        case running
        case complete
        case error
        case timeout
        case cancelled
    }
}

/// Recorded call the agent made to an MCP tool. Populated starting in Phase 2;
/// Phase 1 invocations return an empty `toolCalls` array.
struct ToolCallLog: Codable, Identifiable, Hashable {
    let id: String
    let messageId: String
    let invocationId: String
    let toolName: String
    let input: String
    let output: String?
    let isError: Bool
    let startedAt: String
    let endedAt: String?
    let durationMs: Int?
}

/// Response shape for `GET /api/invocations/:id`.
struct InvocationDetail: Codable {
    let invocation: AgentInvocation
    let messages: [ChatTranscriptMessage]
    let toolCalls: [ToolCallLog]
}
