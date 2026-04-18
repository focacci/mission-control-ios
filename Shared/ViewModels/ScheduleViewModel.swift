import Foundation
import Observation

enum ScheduleViewMode: String, CaseIterable {
    case day   = "Day"
    case month = "Month"
}

@Observable
final class ScheduleViewModel {
    var mode: ScheduleViewMode = .day
    var weekResponse: WeekResponse?
    var isLoading = false
    var error: String?

    var focusDate: Date = Date()

    var focusDateISO: String { focusDate.isoDate }

    var weekStart: String {
        let cal = Calendar.current
        let weekday = cal.component(.weekday, from: focusDate) - 1
        let sunday = cal.date(byAdding: .day, value: -weekday, to: focusDate) ?? focusDate
        return sunday.isoDate
    }

    var weekDates: [Date] {
        let cal = Calendar.current
        let weekday = cal.component(.weekday, from: focusDate) - 1
        let sunday = cal.date(byAdding: .day, value: -weekday, to: focusDate) ?? focusDate
        return (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: sunday) }
    }

    var slotsForFocusDate: [ScheduleSlot] {
        let dateISO = focusDateISO
        return (weekResponse?.slots ?? [])
            .filter { $0.date == dateISO }
            .sorted { $0.datetime < $1.datetime }
    }

    var slotsByDay: [(date: Date, slots: [ScheduleSlot])] {
        weekDates.map { date in
            let iso = date.isoDate
            let slots = (weekResponse?.slots ?? [])
                .filter { $0.date == iso }
                .sorted { $0.datetime < $1.datetime }
            return (date, slots)
        }
    }

    var datesWithSlots: Set<String> {
        Set((weekResponse?.slots ?? []).filter { $0.type == "task" }.map { $0.date })
    }

    func load() async {
        isLoading = true
        error = nil
        do {
            weekResponse = try await APIClient.shared.scheduleWeek(weekStart: weekStart)
        } catch APIError.serverError(let msg) where msg.lowercased().hasPrefix("no week plan") {
            weekResponse = nil
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    func markDone(slot: ScheduleSlot) async {
        do {
            let updated = try await APIClient.shared.doneSlot(id: slot.id)
            replace(slot: updated)
        } catch {
            self.error = error.localizedDescription
        }
    }

    func markSkip(slot: ScheduleSlot) async {
        do {
            let updated = try await APIClient.shared.skipSlot(id: slot.id)
            replace(slot: updated)
        } catch {
            self.error = error.localizedDescription
        }
    }

    func stepWeek(by delta: Int) {
        focusDate = Calendar.current.date(byAdding: .weekOfYear, value: delta, to: focusDate) ?? focusDate
    }

    func stepDay(by delta: Int) {
        focusDate = Calendar.current.date(byAdding: .day, value: delta, to: focusDate) ?? focusDate
    }

    private func replace(slot: ScheduleSlot) {
        guard var slots = weekResponse?.slots else { return }
        if let idx = slots.firstIndex(where: { $0.id == slot.id }) {
            slots[idx] = slot
            weekResponse = WeekResponse(
                weekPlan: weekResponse!.weekPlan,
                slots: slots,
                allocations: weekResponse!.allocations
            )
        }
    }
}
