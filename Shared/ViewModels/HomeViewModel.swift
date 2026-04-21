import Foundation
import Observation

@Observable
final class HomeViewModel {
    var todaySlots: [ScheduleSlot] = []
    var board: BoardResponse?
    var isLoading = false
    var error: String?

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

    var todayTaskSlots: [ScheduleSlot] {
        let today = Date().isoDate
        return todaySlots.filter { $0.type == .task && $0.date == today && $0.taskId != nil }
    }

    func load() async {
        isLoading = true
        error = nil
        do {
            async let slotsTask = APIClient.shared.scheduleToday()
            async let boardTask = APIClient.shared.board()
            (todaySlots, board) = try await (slotsTask, boardTask)
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
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

    func assignTask(taskId: String, slotId: String) async {
        do {
            _ = try await APIClient.shared.assignTask(taskId: taskId, slotId: slotId)
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
