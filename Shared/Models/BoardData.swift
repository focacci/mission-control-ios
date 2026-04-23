import Foundation

struct BoardStats: Codable {
    let total: Int
    let pending: Int
    let inProgress: Int
    let done: Int
    let blocked: Int
    let cancelled: Int
}

struct BoardWeekSummary: Codable {
    let weekPlan: WeekPlan
    let totalSlots: Int
    let assignmentSlots: Int
    let doneSlots: Int
    let skippedSlots: Int
    let pendingSlots: Int
    let allocations: [WeekGoalAllocation]

    var completionPercent: Double {
        guard assignmentSlots > 0 else { return 0 }
        return Double(doneSlots) / Double(assignmentSlots)
    }
}

struct BoardResponse: Codable {
    let goals: [Goal]
    let stats: BoardStats
    let weekSummary: BoardWeekSummary?
}
