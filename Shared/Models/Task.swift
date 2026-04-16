import SwiftUI

// Named MCTask to avoid conflict with Swift concurrency's Task
struct MCTask: Codable, Identifiable {
    let id: String
    let emoji: String?
    let name: String
    let displayName: String?
    let initiativeId: String?
    let status: String         // pending | assigned | in-progress | done | blocked | cancelled
    let objective: String?
    let summary: String?
    let requirements: [Requirement]?
    let tests: [TaskTest]?
    let outputs: [TaskOutput]?
    let initiative: InitiativeRef?
    let slot: SlotRef?

    var resolvedName: String { displayName ?? name }
    var resolvedEmoji: String { emoji ?? "📋" }

    var statusColor: Color {
        switch status {
        case "in-progress": return .blue
        case "pending":     return .gray
        case "assigned":    return .yellow
        case "done":        return .green
        case "blocked":     return .red
        case "cancelled":   return .red
        default:            return .gray
        }
    }

    var statusIcon: String {
        switch status {
        case "in-progress": return "play.circle.fill"
        case "pending":     return "circle"
        case "assigned":    return "circle.dotted"
        case "done":        return "checkmark.circle.fill"
        case "blocked":     return "exclamationmark.circle.fill"
        case "cancelled":   return "xmark.circle.fill"
        default:            return "circle"
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

struct Requirement: Codable, Identifiable {
    let id: String
    let description: String
    let completed: Bool
}

struct TaskTest: Codable, Identifiable {
    let id: String
    let description: String
    let passed: Bool
}

struct TaskOutput: Codable, Identifiable {
    let id: String
    let label: String
    let url: String?
}

struct InitiativeRef: Codable, Identifiable {
    let id: String
    let emoji: String
    let name: String
    let displayName: String?
    var resolvedName: String { displayName ?? name }
}

struct SlotRef: Codable, Identifiable {
    let id: String
}
