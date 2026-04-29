import Foundation
import Observation

@Observable
final class HomeViewModel {
    var todaySlots: [ScheduleSlot] = []
    var board: BoardResponse?
    var isLoading = false
    var error: String?

    /// In-flight autonomous runs (slot_start / brief / manual). Polled every
    /// 10s while the Feed is foregrounded so the "Agent working now" card
    /// reflects current state without a manual refresh.
    var runningInvocations: [AgentInvocation] = []

    /// Failed/timed-out autonomous runs from the last 24h, surfaced so the
    /// user notices instead of them silently rotting in the invocations table.
    var errorInvocations: [AgentInvocation] = []

    /// Last few completed autonomous runs — drives the "Agent finished" cards.
    /// Excludes `userChat` triggers (those are chat replies the user already saw).
    var recentCompleteInvocations: [AgentInvocation] = []

    /// Lookup table for resolving `AgentInvocation.agentId` → display name/emoji
    /// in the Feed cards. Populated once on `load()`; agents change rarely so
    /// no refresh needed during the polling loop.
    var agentsById: [String: Agent] = [:]

    /// Today's brief rows by kind, keyed for the hero card. Missing entries
    /// stay `nil` so the card renders an empty state without falling back to
    /// mock copy.
    var todaysBriefs: [BriefKind: Brief] = [:]

    // Offset in days from today's week (0 = current week)
    var weekOffset: Int = 0

    var selectedDate: Date {
        Calendar.current.date(byAdding: .day, value: weekOffset * 7, to: Date()) ?? Date()
    }

    var selectedDateISO: String {
        selectedDate.isoDate
    }

    var weekDates: [Date] {
        let cal = Calendar.current
        let base = selectedDate
        let weekday = cal.component(.weekday, from: base) - 1 // 0 = Sunday
        let sunday = cal.date(byAdding: .day, value: -weekday, to: base) ?? base
        return (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: sunday) }
    }

    var todayAgentAssignmentSlots: [ScheduleSlot] {
        let today = Date().isoDate
        return todaySlots.filter { $0.type == .agentAssignment && $0.date == today && $0.agentAssignmentId != nil }
    }

    /// Next 1–2 agent-assignment slots scheduled for today that haven't run
    /// yet — drives the "Agent queued" Feed cards (Lane A3).
    var queuedAgentSlots: [ScheduleSlot] {
        let now = Self.currentHHMM()
        return todayAgentAssignmentSlots
            .filter { $0.status != .done && $0.status != .skipped && $0.time >= now }
            .sorted { $0.time < $1.time }
            .prefix(2)
            .map { $0 }
    }

    func agentName(for id: String) -> String {
        agentsById[id]?.displayName ?? "Agent"
    }

    func agentEmoji(for id: String) -> String {
        agentsById[id]?.displayEmoji ?? "🤖"
    }

    func load() async {
        isLoading = true
        error = nil
        let today = Date().isoDate
        do {
            async let slotsTask = APIClient.shared.scheduleToday()
            async let boardTask = APIClient.shared.board()
            async let agentsTask = APIClient.shared.agents()
            async let runningTask = APIClient.shared.invocations(status: "running", limit: 10)
            async let errorTask = APIClient.shared.invocations(status: "error", limit: 10)
            async let completeTask = APIClient.shared.invocations(status: "complete", limit: 10)
            async let briefsTask = APIClient.shared.listBriefs(from: today, to: today)

            let (slots, board, agents, running, errors, complete, briefs) = try await (
                slotsTask, boardTask, agentsTask, runningTask, errorTask, completeTask, briefsTask
            )
            self.todaySlots = slots
            self.board = board
            self.agentsById = Dictionary(uniqueKeysWithValues: agents.map { ($0.id, $0) })
            self.runningInvocations = filterAutonomous(running)
            self.errorInvocations = filterRecentErrors(errors)
            self.recentCompleteInvocations = filterAutonomous(complete).prefix(3).map { $0 }
            self.todaysBriefs = Dictionary(uniqueKeysWithValues: briefs.map { ($0.kind, $0) })
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    /// Lightweight refresh used by the Feed's polling loop. Re-fetches only
    /// the invocation lanes that change minute-to-minute — slots, board, and
    /// agents are stable enough to refresh on `load()` only.
    func refreshLive() async {
        do {
            async let runningTask = APIClient.shared.invocations(status: "running", limit: 10)
            async let errorTask = APIClient.shared.invocations(status: "error", limit: 10)
            async let completeTask = APIClient.shared.invocations(status: "complete", limit: 10)
            let (running, errors, complete) = try await (runningTask, errorTask, completeTask)
            self.runningInvocations = filterAutonomous(running)
            self.errorInvocations = filterRecentErrors(errors)
            self.recentCompleteInvocations = filterAutonomous(complete).prefix(3).map { $0 }
        } catch {
            // Swallow polling errors — the next tick will retry. Surfacing
            // these would flap the error banner every 10s on a flaky network.
        }
    }

    private func filterAutonomous(_ invocations: [AgentInvocation]) -> [AgentInvocation] {
        invocations.filter { $0.trigger != .userChat }
    }

    private func filterRecentErrors(_ invocations: [AgentInvocation]) -> [AgentInvocation] {
        let cutoff = Date().addingTimeInterval(-24 * 60 * 60)
        let parser = ISO8601DateFormatter()
        parser.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return filterAutonomous(invocations).filter { inv in
            guard let endedAt = inv.endedAt,
                  let date = parser.date(from: endedAt) ?? ISO8601DateFormatter().date(from: endedAt)
            else { return true }
            return date > cutoff
        }
    }

    private static func currentHHMM() -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        f.timeZone = TimeZone(identifier: "America/New_York")
        return f.string(from: Date())
    }

    func doneSlot(_ slot: ScheduleSlot) async {
        do {
            let updated = try await APIClient.shared.doneSlot(id: slot.id)
            replace(slot: updated)
        } catch {
            self.error = error.localizedDescription
        }
    }

    func skipSlot(_ slot: ScheduleSlot) async {
        do {
            let updated = try await APIClient.shared.skipSlot(id: slot.id)
            replace(slot: updated)
        } catch {
            self.error = error.localizedDescription
        }
    }

    func assignAgentAssignment(agentAssignmentId: String, slotId: String) async {
        do {
            _ = try await APIClient.shared.assignAgentAssignment(agentAssignmentId: agentAssignmentId, slotId: slotId)
            await load()
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func replace(slot: ScheduleSlot) {
        if let idx = todaySlots.firstIndex(where: { $0.id == slot.id }) {
            todaySlots[idx] = slot
        }
    }
}

// MARK: - Rosary

enum RosaryMystery: String, CaseIterable {
    case joyful    = "Joyful"
    case luminous  = "Luminous"
    case sorrowful = "Sorrowful"
    case glorious  = "Glorious"

    static func forDate(_ date: Date) -> RosaryMystery {
        let weekday = Calendar.current.component(.weekday, from: date)
        switch weekday {
        case 1: return .glorious   // Sunday
        case 2: return .joyful     // Monday
        case 3: return .sorrowful  // Tuesday
        case 4: return .glorious   // Wednesday
        case 5: return .luminous   // Thursday
        case 6: return .sorrowful  // Friday
        case 7: return .joyful     // Saturday
        default: return .joyful
        }
    }

    var mysteries: [(index: Int, name: String)] {
        switch self {
        case .joyful:
            return [(1, "The Annunciation"),
                    (2, "The Visitation"),
                    (3, "The Nativity"),
                    (4, "The Presentation"),
                    (5, "Finding in the Temple")]
        case .luminous:
            return [(1, "The Baptism of Christ"),
                    (2, "The Wedding at Cana"),
                    (3, "Proclamation of the Kingdom"),
                    (4, "The Transfiguration"),
                    (5, "Institution of the Eucharist")]
        case .sorrowful:
            return [(1, "Agony in the Garden"),
                    (2, "Scourging at the Pillar"),
                    (3, "Crowning with Thorns"),
                    (4, "Carrying the Cross"),
                    (5, "The Crucifixion")]
        case .glorious:
            return [(1, "The Resurrection"),
                    (2, "The Ascension"),
                    (3, "Descent of the Holy Spirit"),
                    (4, "The Assumption"),
                    (5, "Coronation of Our Lady")]
        }
    }
}

// MARK: - Rosary State (UserDefaults per date)

@Observable
final class RosaryState {
    private let date: String

    var checkedMysteries: Set<Int> {
        didSet { persistMysteries() }
    }

    var checkedScriptures: Set<String> {
        didSet { persistScriptures() }
    }

    init(date: String = Date().isoDate) {
        self.date = date
        let saved = UserDefaults.standard.array(forKey: "rosary-\(date)") as? [Int] ?? []
        self.checkedMysteries = Set(saved)
        let savedScriptures = UserDefaults.standard.array(forKey: "scripture-\(date)") as? [String] ?? []
        self.checkedScriptures = Set(savedScriptures)
    }

    func toggle(index: Int) {
        if checkedMysteries.contains(index) {
            checkedMysteries.remove(index)
        } else {
            checkedMysteries.insert(index)
        }
    }

    func toggleScripture(citation: String) {
        if checkedScriptures.contains(citation) {
            checkedScriptures.remove(citation)
        } else {
            checkedScriptures.insert(citation)
        }
    }

    private func persistMysteries() {
        UserDefaults.standard.set(Array(checkedMysteries), forKey: "rosary-\(date)")
    }

    private func persistScriptures() {
        UserDefaults.standard.set(Array(checkedScriptures), forKey: "scripture-\(date)")
    }
}

// MARK: - Daily Note (UserDefaults per date)

@Observable
final class DailyNote {
    let date: String

    var text: String {
        didSet { UserDefaults.standard.set(text, forKey: "note-\(date)") }
    }

    init(date: String = Date().isoDate) {
        self.date = date
        self.text = UserDefaults.standard.string(forKey: "note-\(date)") ?? ""
    }
}

// MARK: - Date helper

extension Date {
    var isoDate: String { ISO8601DateFormatter.shared.string(from: self) }
}

extension ISO8601DateFormatter {
    static let shared: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withFullDate]
        f.timeZone = TimeZone(identifier: "America/New_York")!
        return f
    }()
}
