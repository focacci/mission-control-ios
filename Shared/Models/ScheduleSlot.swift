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

// MARK: - Slot Type / Status

enum SlotType: String, Codable, Hashable, CaseIterable {
    case maintenance
    case planning
    case task
    case brief
    case flex
    case unknown

    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = SlotType(rawValue: raw) ?? .unknown
    }
}

enum SlotStatus: String, Codable, Hashable, CaseIterable {
    case pending
    case inProgress = "in-progress"
    case done
    case skipped
    case unknown

    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = SlotStatus(rawValue: raw) ?? .unknown
    }

    var displayName: String {
        switch self {
        case .pending:    return "Pending"
        case .inProgress: return "In Progress"
        case .done:       return "Done"
        case .skipped:    return "Skipped"
        case .unknown:    return "Unknown"
        }
    }
}

// MARK: - Schedule Slot

struct ScheduleSlot: Codable, Identifiable, Hashable {
    let id: String
    let weekPlanId: String
    let date: String
    let time: String
    let datetime: String
    let type: SlotType
    var status: SlotStatus
    var taskId: String?
    let goalId: String?
    let note: String?
    let dayOfWeek: String
    var task: MCTask?

    var typeIcon: String {
        switch type {
        case .maintenance: return "wrench.and.screwdriver"
        case .planning:    return "calendar"
        case .brief:       return "sun.horizon"
        case .task:        return "checkmark.circle"
        case .flex, .unknown: return "circle.dotted"
        }
    }

    var typeLabel: String {
        switch type {
        case .maintenance: return "Maintenance"
        case .planning:    return "Planning"
        case .brief:
            switch time {
            case "07:00": return "Morning Brief"
            case "12:30": return "Afternoon Brief"
            case "19:00": return "Evening Brief"
            default:      return "Brief"
            }
        case .task:        return task?.name ?? "Task"
        case .flex, .unknown: return "Flex"
        }
    }

    var statusColor: Color {
        switch status {
        case .done:       return .green
        case .inProgress: return .blue
        case .skipped:    return .secondary
        case .pending, .unknown: return .primary
        }
    }

    var statusIcon: String {
        switch status {
        case .done:       return "checkmark.circle.fill"
        case .inProgress: return "play.circle.fill"
        case .skipped:    return "forward.circle"
        case .pending, .unknown: return "circle"
        }
    }

    var isDimmed: Bool {
        type == .maintenance || status == .skipped
    }

    /// True for slots the user can claim with a task (an open flex/task slot).
    var isOpenSlot: Bool {
        taskId == nil && (type == .flex || type == .task)
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
    let weekPlan: WeekPlan?
    let slots: [ScheduleSlot]
    let allocations: [WeekGoalAllocation]
}

// MARK: - Generate Response (same shape)

typealias GenerateWeekResponse = WeekResponse

// MARK: - Range Response

struct RangeResponse: Codable {
    let from: String
    let to: String
    let slots: [ScheduleSlot]
}
