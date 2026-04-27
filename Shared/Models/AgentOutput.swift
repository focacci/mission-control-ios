import SwiftUI

/// Structured record of one autonomous run of an Agent Assignment. Distinct
/// from chat history — captures the input the agent received, an ordered
/// timeline of `thinking` / `tool_call` / `text` steps, and the final response.
struct AgentOutput: Codable, Identifiable, Hashable {
    let id: String
    let agentAssignmentId: String
    let agentId: String?
    let status: Status
    let input: String
    let response: String?
    let model: String?
    let tokensIn: Int
    let tokensOut: Int
    let startedAt: String
    let endedAt: String?
    let error: String?

    enum Status: String, Codable, CaseIterable {
        case running, complete, error, cancelled

        var icon: String {
            switch self {
            case .running:   return "circle.dotted.circle.fill"
            case .complete:  return "checkmark.circle.fill"
            case .error:     return "exclamationmark.triangle.fill"
            case .cancelled: return "xmark.circle.fill"
            }
        }

        var color: Color {
            switch self {
            case .running:   return .green
            case .complete:  return .blue
            case .error:     return .red
            case .cancelled: return .secondary
            }
        }

        var label: String {
            switch self {
            case .running:   return "Running"
            case .complete:  return "Complete"
            case .error:     return "Error"
            case .cancelled: return "Cancelled"
            }
        }
    }
}

/// One ordered event from an Agent Output timeline.
struct AgentOutputStep: Codable, Identifiable, Hashable {
    let id: String
    let outputId: String
    let kind: Kind
    /// Populated for `thinking` and `text`; `nil` for `tool_call`.
    let content: String?
    let toolName: String?
    /// Raw JSON string — decoded on demand for display.
    let toolInput: String?
    let toolOutput: String?
    let isError: Bool
    let sortOrder: Int
    let startedAt: String
    let endedAt: String?
    let durationMs: Int?

    enum Kind: String, Codable {
        case thinking
        case toolCall = "tool_call"
        case text
    }
}

/// Response shape for `GET /api/agent-outputs/:id`.
struct AgentOutputDetail: Codable, Hashable {
    let output: AgentOutput
    let steps: [AgentOutputStep]
}
