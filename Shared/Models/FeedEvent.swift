import Foundation
import EventKit

/// One entry in the Feed's past-only event list. Combines agent activity and
/// revealed briefs today; later PRs add Rosary snapshots.
enum FeedEvent: Identifiable, Hashable {
    case agentRunning(AgentInvocation)
    case agentError(AgentInvocation)
    case agentFinished(AgentInvocation)
    case briefRevealed(Brief)
    case calendarEvent(EKEvent)

    var id: String {
        switch self {
        case .agentRunning(let i):  return "running:\(i.id)"
        case .agentError(let i):    return "error:\(i.id)"
        case .agentFinished(let i): return "finished:\(i.id)"
        case .briefRevealed(let b): return "brief:\(b.id)"
        case .calendarEvent(let e): return calendarEventId(e)
        }
    }

    var sortKey: Date {
        switch self {
        case .agentRunning(let i):  return parseISOTimestamp(i.startedAt) ?? .distantPast
        case .agentError(let i):    return parseISOTimestamp(i.endedAt) ?? .distantPast
        case .agentFinished(let i): return parseISOTimestamp(i.endedAt) ?? .distantPast
        case .briefRevealed(let b): return parseRevealAt(b.revealAt) ?? .distantPast
        case .calendarEvent(let e): return e.endDate
        }
    }

    var category: FeedFilterCategory {
        switch self {
        case .agentRunning, .agentError, .agentFinished: return .agents
        case .briefRevealed:                              return .briefs
        case .calendarEvent:                              return .you
        }
    }
}

// `EKEvent.eventIdentifier` is nullable for some store types (e.g. unsaved
// or certain delegated calendars). Fall back to a deterministic composite so
// SwiftUI's `ForEach` doesn't collapse rows that happen to share `nil`.
private func calendarEventId(_ e: EKEvent) -> String {
    if let id = e.eventIdentifier, !id.isEmpty {
        return "cal:\(id)"
    }
    return "cal:\(e.calendarItemIdentifier):\(e.startDate.timeIntervalSince1970)"
}

/// Filter chip identity for `EventListSection`. PR 1 ships the model only;
/// PR 4 wires the chips into the section.
enum FeedFilterCategory: String, CaseIterable, Hashable {
    case all, agents, briefs, schedule, you
}

/// Brief slot status surfaced in the Feed header. The `.drafting` case
/// carries live partial-counts pulled from `Brief.body.sections` while the
/// drafting pipeline appends evidence. Counts increment over the polling
/// loop so the user sees the brief assembling in real time.
enum HeaderBriefStatus: Hashable {
    case none
    case scheduled(kind: BriefKind, revealAt: String?)
    case drafting(brief: Brief, agentRuns: Int, openQuestions: Int, accomplishments: Int)
    case ready(brief: Brief)
    case acknowledged(brief: Brief)
}

private func parseISOTimestamp(_ s: String?) -> Date? {
    guard let s else { return nil }
    let frac = ISO8601DateFormatter()
    frac.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let d = frac.date(from: s) { return d }
    return ISO8601DateFormatter().date(from: s)
}

private func parseRevealAt(_ s: String?) -> Date? {
    guard let s else { return nil }
    let f = DateFormatter()
    f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
    f.timeZone = TimeZone(identifier: "America/New_York")
    return f.date(from: s)
}
