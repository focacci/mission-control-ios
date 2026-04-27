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
