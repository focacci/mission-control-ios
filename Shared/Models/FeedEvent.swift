import Foundation

/// One entry in the Feed's past-only event list. Combines agent activity and
/// revealed briefs today; later PRs add calendar events and Rosary snapshots.
enum FeedEvent: Identifiable, Hashable {
    case agentRunning(AgentInvocation)
    case agentError(AgentInvocation)
    case agentFinished(AgentInvocation)
    case briefRevealed(Brief)

    var id: String {
        switch self {
        case .agentRunning(let i):  return "running:\(i.id)"
        case .agentError(let i):    return "error:\(i.id)"
        case .agentFinished(let i): return "finished:\(i.id)"
        case .briefRevealed(let b): return "brief:\(b.id)"
        }
    }

    var sortKey: Date {
        switch self {
        case .agentRunning(let i):  return parseISOTimestamp(i.startedAt) ?? .distantPast
        case .agentError(let i):    return parseISOTimestamp(i.endedAt) ?? .distantPast
        case .agentFinished(let i): return parseISOTimestamp(i.endedAt) ?? .distantPast
        case .briefRevealed(let b): return parseRevealAt(b.revealAt) ?? .distantPast
        }
    }

    var category: FeedFilterCategory {
        switch self {
        case .agentRunning, .agentError, .agentFinished: return .agents
        case .briefRevealed:                              return .briefs
        }
    }
}

/// Filter chip identity for `EventListSection`. PR 1 ships the model only;
/// PR 4 wires the chips into the section.
enum FeedFilterCategory: String, CaseIterable, Hashable {
    case all, agents, briefs, schedule, you
}

/// Brief slot status surfaced in the Feed header. PR 3 extends with a
/// `.drafting` case carrying live partial-counts.
enum HeaderBriefStatus: Hashable {
    case none
    case scheduled(kind: BriefKind, revealAt: String?)
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
