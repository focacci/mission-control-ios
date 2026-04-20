import SwiftUI

// Named MCTask to avoid conflict with Swift concurrency's Task
struct MCTask: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let initiativeId: String?
    let status: String         // pending | assigned | in-progress | done | blocked | cancelled
    let objective: String?
    let summary: String?
    let requirements: [Requirement]?
    let tests: [TaskTest]?
    let outputs: [TaskOutput]?
    let initiative: InitiativeRef?
    let goal: GoalRef?
    let slot: SlotRef?

    var statusColor: Color {
        switch status {
        case "pending":     return .gray
        case "assigned":    return .yellow
        case "in-progress": return .green
        case "done":        return .blue
        case "blocked":     return .orange
        case "cancelled":   return .red
        default:            return .gray
        }
    }

    var statusIcon: String {
        switch status {
        case "pending":     return "circle.dotted"
        case "assigned":    return "calendar.circle"
        case "in-progress": return "circle.circle.fill"
        case "done":        return "checkmark.circle.fill"
        case "blocked":     return "pause.circle.fill"
        case "cancelled":   return "xmark.circle.fill"
        default:            return "circle.dotted"
        }
    }

    var statusLabel: String {
        switch status {
        case "in-progress": return "In Progress"
        default: return status.prefix(1).uppercased() + status.dropFirst()
        }
    }

    var requirementProgress: String {
        guard let reqs = requirements, !reqs.isEmpty else { return "" }
        let done = reqs.filter(\.completed).count
        return "\(done)/\(reqs.count)"
    }

    var canStart: Bool {
        status == "pending" || status == "assigned" || status == "blocked"
    }

    var canComplete: Bool { status == "in-progress" }
    var canBlock: Bool    { status == "in-progress" }
    var isTerminal: Bool  { status == "done" || status == "cancelled" }
}

struct Requirement: Codable, Identifiable, Hashable {
    let id: String
    let description: String
    let completed: Bool
}

struct TaskTest: Codable, Identifiable, Hashable {
    let id: String
    let description: String
    let passed: Bool
}

struct TaskOutput: Codable, Identifiable, Hashable {
    let id: String
    let label: String
    let url: String?
}

struct InitiativeRef: Codable, Identifiable, Hashable {
    let id: String
    let emoji: String
    let name: String
}

struct SlotRef: Codable, Identifiable, Hashable {
    let id: String
    let date: String
    let time: String
    let datetime: String
    let type: String
}
