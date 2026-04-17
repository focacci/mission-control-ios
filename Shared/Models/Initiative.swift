import SwiftUI

struct Initiative: Codable, Identifiable, Hashable {
    let id: String
    let emoji: String
    let name: String
    let goalId: String?
    let status: String         // active | backlog | paused | completed
    let mission: String?
    let goal: GoalRef?
    let tasks: [MCTask]?

    var statusColor: Color {
        switch status {
        case "active":    return .green
        case "paused":    return .orange
        case "backlog":   return .gray
        case "completed": return .blue
        default:          return .gray
        }
    }

    var statusLabel: String {
        status.prefix(1).uppercased() + status.dropFirst()
    }

    var statusIcon: String {
        switch status {
        case "active":    return "circle.fill"
        case "paused":    return "pause.circle.fill"
        case "completed": return "checkmark.circle.fill"
        default:          return "circle"
        }
    }
}

// Lightweight goal reference returned inside initiative detail
struct GoalRef: Codable, Identifiable, Hashable {
    let id: String
    let emoji: String
    let name: String
}
