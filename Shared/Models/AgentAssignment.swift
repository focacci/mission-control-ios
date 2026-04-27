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
    var description: String?
    var agentId: String?
    /// pending | scheduled | in-progress | done | blocked
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
        case "scheduled":   return "clock.fill"
        case "in-progress": return "circle.dotted.circle.fill"
        case "done":        return "checkmark.circle.fill"
        case "blocked":     return "pause.circle.fill"
        default:            return "circle.dotted"
        }
    }

    var statusColor: Color {
        switch status {
        case "pending":     return .secondary
        case "scheduled":   return .orange
        case "in-progress": return .green
        case "done":        return .blue
        case "blocked":     return .red
        default:            return .secondary
        }
    }

    var statusLabel: String {
        switch status {
        case "in-progress": return "In Progress"
        default: return status.prefix(1).uppercased() + status.dropFirst()
        }
    }

    var isInProgress: Bool { status == "in-progress" }
    var isDone: Bool { status == "done" }
    var canStart: Bool { status == "pending" || status == "scheduled" || status == "blocked" }
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

/// Reusable status icon view that animates the in-progress glyph clockwise.
struct AgentAssignmentStatusIcon: View {
    let assignment: AgentAssignment
    var font: Font = .body

    @State private var rotation: Double = 0

    var body: some View {
        Image(systemName: assignment.statusIcon)
            .font(font)
            .foregroundStyle(assignment.statusColor)
            .rotationEffect(.degrees(assignment.isInProgress ? rotation : 0))
            .onAppear { startIfNeeded() }
            .onChange(of: assignment.status) { _, _ in startIfNeeded() }
    }

    private func startIfNeeded() {
        guard assignment.isInProgress else { return }
        rotation = 0
        withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
            rotation = 360
        }
    }
}
