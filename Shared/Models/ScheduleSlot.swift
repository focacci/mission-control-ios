import Foundation
import SwiftUI

// MARK: - Week Plan

struct WeekPlan: Codable, Identifiable, Hashable {
    let id: String
    let weekStart: String
    let weekEnd: String
    let generatedAt: String
    let sprintSlots: Int
    let steadySlots: Int
    let simmerSlots: Int
    let fixedSlots: Int
    let flexSlots: Int
}

// MARK: - Schedule Slot

struct ScheduleSlot: Codable, Identifiable, Hashable {
    let id: String
    let weekPlanId: String
    let date: String
    let time: String
    let datetime: String
    let type: String       // maintenance | planning | task | brief | flex
    let status: String     // pending | in-progress | done | skipped
    let taskId: String?
    let goalId: String?
    let note: String?
    let dayOfWeek: String
    let task: MCTask?

    var typeIcon: String {
        switch type {
        case "maintenance": return "wrench.and.screwdriver"
        case "planning":    return "calendar"
        case "brief":       return "sun.horizon"
        case "task":        return "checkmark.circle"
        default:            return "circle.dotted"
        }
    }

    var typeLabel: String {
        switch type {
        case "maintenance": return "Maintenance"
        case "planning":    return "Planning"
        case "brief":
            switch time {
            case "07:00": return "Morning Brief"
            case "12:30": return "Afternoon Brief"
            case "19:00": return "Evening Brief"
            default:      return "Brief"
            }
        case "task":        return task?.name ?? "Task"
        default:            return "Flex"
        }
    }

    var statusColor: Color {
        switch status {
        case "done":        return .green
        case "in-progress": return .blue
        case "skipped":     return .secondary
        default:            return .primary
        }
    }

    var statusIcon: String {
        switch status {
        case "done":        return "checkmark.circle.fill"
        case "in-progress": return "play.circle.fill"
        case "skipped":     return "forward.circle"
        default:            return "circle"
        }
    }

    var isDimmed: Bool {
        type == "maintenance" || status == "skipped"
    }
}

// MARK: - Week Goal Allocation

struct WeekGoalAllocation: Codable, Identifiable, Hashable {
    let id: String
    let weekPlanId: String
    let goalId: String
    let targetSlots: Int
    let assignedSlots: Int
}

// MARK: - Week Response

struct WeekResponse: Codable {
    let weekPlan: WeekPlan
    let slots: [ScheduleSlot]
    let allocations: [WeekGoalAllocation]
}

// MARK: - Generate Response (same shape)

typealias GenerateWeekResponse = WeekResponse
