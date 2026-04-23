import SwiftUI

// Named MCTask to avoid conflict with Swift concurrency's Task
struct MCTask: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let initiativeId: String?
    let status: String         // pending | in-progress | done | blocked | cancelled
    let objective: String?
    let summary: String?
    var requirements: [Requirement]?
    var agentAssignments: [AgentAssignment]?
    let initiative: InitiativeRef?
    let goal: GoalRef?

    var statusColor: Color {
        switch status {
        case "pending":     return .gray
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

    var agentAssignmentProgress: String {
        guard let aas = agentAssignments, !aas.isEmpty else { return "" }
        let done = aas.filter(\.completed).count
        return "\(done)/\(aas.count)"
    }

    var canStart: Bool {
        status == "pending" || status == "blocked"
    }

    var canComplete: Bool { status == "in-progress" }
    var canBlock: Bool    { status == "in-progress" }
    var isTerminal: Bool  { status == "done" || status == "cancelled" }
}

struct Requirement: Codable, Identifiable, Hashable {
    let id: String
    var description: String
    var completed: Bool
    var tests: [RequirementTest]?

    var testsProgress: String {
        guard let t = tests, !t.isEmpty else { return "" }
        let passed = t.filter(\.passed).count
        return "\(passed)/\(t.count)"
    }
}

struct RequirementTest: Codable, Identifiable, Hashable {
    let id: String
    var description: String
    var passed: Bool
}

struct InitiativeRef: Codable, Identifiable, Hashable {
    let id: String
    let emoji: String
    let name: String
}
