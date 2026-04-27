import SwiftUI

/// Discrete unit of work an agent can do on the user's behalf. Each assignment
/// is parented to **exactly one** of a Goal, Initiative, or Task — the other
/// two id columns are `nil`. Agent Assignments are what get scheduled into
/// time slots; the parent itself is never scheduled directly.
struct AgentAssignment: Codable, Identifiable, Hashable {
    let id: String
    let goalId: String?
    let initiativeId: String?
    let taskId: String?
    var title: String
    var instructions: String
    var agentId: String?
    /// pending | in-progress | done | blocked
    var status: String
    var completedAt: String?
    var sortOrder: Int
    var createdAt: String
    var updatedAt: String
    /// Time slots this assignment is scheduled into. One assignment can span
    /// multiple slots.
    var slots: [AgentAssignmentSlotRef]?

    var statusIcon: String {
        switch status {
        case "pending":     return "circle.dotted"
        case "in-progress": return "circle.circle.fill"
        case "done":        return "checkmark.circle.fill"
        case "blocked":     return "pause.circle.fill"
        default:            return "circle.dotted"
        }
    }

    var statusColor: Color {
        switch status {
        case "pending":     return .secondary
        case "in-progress": return .green
        case "done":        return .blue
        case "blocked":     return .orange
        default:            return .secondary
        }
    }

    var statusLabel: String {
        switch status {
        case "in-progress": return "In Progress"
        default: return status.prefix(1).uppercased() + status.dropFirst()
        }
    }

    var isDone: Bool { status == "done" }
    var canStart: Bool { status == "pending" || status == "blocked" }
    var canComplete: Bool { status == "in-progress" }
    var canBlock: Bool { status == "in-progress" }
    var canReopen: Bool { status == "done" || status == "blocked" }
}

/// Lightweight reference to a slot the agent assignment occupies — included
/// when the API enriches an assignment with its scheduling info.
struct AgentAssignmentSlotRef: Codable, Identifiable, Hashable {
    let id: String
    let date: String
    let time: String
    let datetime: String
    let dayOfWeek: String
}
