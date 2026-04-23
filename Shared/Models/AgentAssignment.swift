import SwiftUI

/// Discrete unit of work an agent can do on the user's behalf to help them
/// complete a Task. Agent Assignments are what get scheduled into time slots;
/// the parent Task itself is human-driven and is not scheduled directly.
struct AgentAssignment: Codable, Identifiable, Hashable {
    let id: String
    let taskId: String
    var title: String
    var instructions: String
    var agentId: String?
    var completed: Bool
    var completedAt: String?
    var sortOrder: Int
    var createdAt: String
    var updatedAt: String
    /// Time slots this assignment is scheduled into. One assignment can span
    /// multiple slots.
    var slots: [AgentAssignmentSlotRef]?

    var statusIcon: String {
        completed ? "checkmark.circle.fill" : "circle.dotted"
    }

    var statusColor: Color {
        completed ? .green : .secondary
    }

    var statusLabel: String {
        completed ? "Completed" : "Pending"
    }
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
