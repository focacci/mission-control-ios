import Foundation

struct BoardStats: Codable {
    let total: Int
    let pending: Int
    let assigned: Int
    let inProgress: Int
    let done: Int
    let blocked: Int
    let cancelled: Int
}

struct BoardWeekSummary: Codable {
    let weekPlan: WeekPlan
    let totalSlots: Int
    let taskSlots: Int
    let doneSlots: Int
    let skippedSlots: Int
    let pendingSlots: Int
    let allocations: [WeekGoalAllocation]

    var completionPercent: Double {
        guard taskSlots > 0 else { return 0 }
        return Double(doneSlots) / Double(taskSlots)
    }
}

struct BoardResponse: Codable {
    let goals: [Goal]
    let stats: BoardStats
    let weekSummary: BoardWeekSummary?
}
