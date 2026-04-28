import Foundation

/// Parsed form of a `MessagePart.navigate.route` string. The agent emits free-
/// form path strings (`/tasks/<id>`, `/schedule?date=2026-04-30`, `/home`,
/// etc.); `DeepLink.parse` turns them into a typed enum so the iOS nav stack
/// can dispatch without scattering string parsing throughout view code.
///
/// `unknown` is the safe fallback — `NavigateRow` renders unknown routes as
/// plain non-tappable text per IOS_MESSAGE_PARTS_PLAN §5.3, so that a future
/// server adding a new path doesn't break older clients.
enum DeepLink: Equatable, Hashable {
    case task(id: String)
    case goal(id: String)
    case initiative(id: String)
    case agentAssignment(id: String)
    case schedule(date: Date?)
    case home
    case unknown(raw: String)

    /// `true` for any case that resolves to a real destination iOS knows how
    /// to open. `false` only for `.unknown`.
    var isResolved: Bool {
        if case .unknown = self { return false }
        return true
    }

    /// Pure parser. `route` is the raw value from `MessagePart.navigate`; we
    /// never touch the network and never throw — anything we can't recognize
    /// becomes `.unknown(raw:)` so the renderer can still display the label.
    static func parse(_ route: String) -> DeepLink {
        let trimmed = route.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .unknown(raw: route) }

        // Split off query string for `/schedule?date=…` style routes.
        let (pathOnly, query) = splitQuery(trimmed)
        let segments = pathOnly
            .split(separator: "/", omittingEmptySubsequences: true)
            .map(String.init)

        guard let head = segments.first?.lowercased() else {
            return .unknown(raw: route)
        }

        switch head {
        case "home":
            return .home

        case "tasks", "task":
            if segments.count >= 2 { return .task(id: segments[1]) }
            return .unknown(raw: route)

        case "goals", "goal":
            if segments.count >= 2 { return .goal(id: segments[1]) }
            return .unknown(raw: route)

        case "initiatives", "initiative":
            if segments.count >= 2 { return .initiative(id: segments[1]) }
            return .unknown(raw: route)

        case "agent-assignments", "assignments", "agentAssignments":
            if segments.count >= 2 { return .agentAssignment(id: segments[1]) }
            return .unknown(raw: route)

        case "schedule":
            // `/schedule`, `/schedule/today`, `/schedule/<iso-date>`, or
            // `/schedule?date=<iso>`.
            if segments.count >= 2 {
                let token = segments[1]
                if token.lowercased() == "today" {
                    return .schedule(date: Date())
                }
                if let d = parseISODate(token) {
                    return .schedule(date: d)
                }
            }
            if let q = query["date"], let d = parseISODate(q) {
                return .schedule(date: d)
            }
            return .schedule(date: nil)

        default:
            return .unknown(raw: route)
        }
    }

    // MARK: - Helpers

    private static func splitQuery(_ raw: String) -> (path: String, query: [String: String]) {
        guard let qIdx = raw.firstIndex(of: "?") else { return (raw, [:]) }
        let path = String(raw[..<qIdx])
        let qStr = String(raw[raw.index(after: qIdx)...])
        var out: [String: String] = [:]
        for pair in qStr.split(separator: "&") {
            let kv = pair.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
            guard kv.count == 2 else { continue }
            out[String(kv[0])] = String(kv[1]).removingPercentEncoding ?? String(kv[1])
        }
        return (path, out)
    }

    private static func parseISODate(_ s: String) -> Date? {
        // Try full ISO8601 first, then YYYY-MM-DD.
        let iso = ISO8601DateFormatter()
        if let d = iso.date(from: s) { return d }
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.timeZone = TimeZone(secondsFromGMT: 0)
        f.dateFormat = "yyyy-MM-dd"
        return f.date(from: s)
    }
}
