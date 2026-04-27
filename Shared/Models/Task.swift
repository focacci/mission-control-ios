import SwiftUI

// Named MCTask to avoid conflict with Swift concurrency's Task
struct MCTask: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let initiativeId: String?
    let status: String         // pending | done
    let objective: String?
    let summary: String?
    var requirements: [Requirement]?
    var agentAssignments: [AgentAssignment]?
    let initiative: InitiativeRef?
    let goal: GoalRef?

    var statusColor: Color {
        status == "done" ? .blue : .gray
    }

    var statusIcon: String {
        status == "done" ? "checkmark.circle.fill" : "circle.dotted"
    }

    var statusLabel: String {
        status == "done" ? "Done" : "Pending"
    }

    var isDone: Bool { status == "done" }

    var requirementProgress: String {
        guard let reqs = requirements, !reqs.isEmpty else { return "" }
        let done = reqs.filter(\.completed).count
        return "\(done)/\(reqs.count)"
    }

    var agentAssignmentProgress: String {
        guard let aas = agentAssignments, !aas.isEmpty else { return "" }
        let done = aas.filter(\.isDone).count
        return "\(done)/\(aas.count)"
    }
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
