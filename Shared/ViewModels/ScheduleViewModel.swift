import Foundation
import Observation

enum ScheduleViewMode: String, CaseIterable {
    case day   = "Day"
    case month = "Month"
    case year  = "Year"
}

@Observable
final class ScheduleViewModel {
    var mode: ScheduleViewMode = .day
    var weekResponse: WeekResponse?
    var isLoading = false
    var error: String?

    var focusDate: Date = Date()

    /// All slots we've ever loaded, keyed by ISO date. Accumulates as the
    /// user browses — month/year views pull larger ranges in one call.
    /// `weekResponse` stays the source of truth for the *current* week (it
    /// also carries `weekPlan` and `allocations`, which range loads don't).
    private(set) var slotsByDate: [String: [ScheduleSlot]] = [:]

    /// Ranges we've already fetched, so we don't refetch on every navigation.
    private var loadedRanges: [(from: String, to: String)] = []

    var focusDateISO: String { focusDate.isoDate }

    /// Identifies the data range needed for the current (mode, focusDate) pair.
    /// Navigating within the same range (e.g., stepping days in the same week)
    /// produces the same key, so the view's `.task(id:)` can skip redundant
    /// fetches. Mode changes or crossing a range boundary produce a new key.
    var loadKey: LoadKey {
        let cal = Calendar.current
        let key: String
        switch mode {
        case .day:
            key = weekStart
        case .month:
            let c = cal.dateComponents([.year, .month], from: focusDate)
            key = String(format: "%04d-%02d", c.year ?? 0, c.month ?? 0)
        case .year:
            key = String(format: "%04d", cal.component(.year, from: focusDate))
        }
        return LoadKey(mode: mode, range: key)
    }

    struct LoadKey: Hashable {
        let mode: ScheduleViewMode
        let range: String
    }

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
        slotsByDate[focusDateISO] ?? []
    }

    var slotsByDay: [(date: Date, slots: [ScheduleSlot])] {
        weekDates.map { date in (date, slotsByDate[date.isoDate] ?? []) }
    }

    var datesWithSlots: Set<String> {
        var set: Set<String> = []
        for (iso, slots) in slotsByDate where slots.contains(where: { $0.type == .task }) {
            set.insert(iso)
        }
        return set
    }

    /// Whether any loaded slot falls inside the given month (for year-view dots).
    func monthHasSlots(year: Int, month: Int) -> Bool {
        for (iso, slots) in slotsByDate {
            guard slots.contains(where: { $0.type == .task }) else { continue }
            let parts = iso.split(separator: "-")
            guard parts.count == 3,
                  let y = Int(parts[0]), let m = Int(parts[1]),
                  y == year, m == month else { continue }
            return true
        }
        return false
    }

    // MARK: - Loading

    /// Loads data for the current mode. Week/day use `scheduleWeek` (to
    /// get `weekPlan` + `allocations` for the current week); month pulls
    /// the 6-week window spanning the visible grid; year pulls the whole
    /// calendar year in one call.
    func load() async {
        isLoading = true
        error = nil
        defer { isLoading = false }
        do {
            switch mode {
            case .day:
                let resp = try await APIClient.shared.scheduleWeek(weekStart: weekStart)
                weekResponse = resp
                mergeSlots(resp.slots)
            case .month:
                try await loadMonthRange()
            case .year:
                try await loadYearRange()
            }
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func loadMonthRange() async throws {
        let cal = Calendar.current
        let comps = cal.dateComponents([.year, .month], from: focusDate)
        guard let firstOfMonth = cal.date(from: comps),
              let range = cal.range(of: .day, in: .month, for: firstOfMonth),
              let lastOfMonth = cal.date(byAdding: .day, value: range.count - 1, to: firstOfMonth)
        else { return }

        // Extend to the calendar-grid boundaries (Sun start, Sat end).
        let leading = cal.component(.weekday, from: firstOfMonth) - 1
        let trailing = 6 - (cal.component(.weekday, from: lastOfMonth) - 1)
        guard let from = cal.date(byAdding: .day, value: -leading, to: firstOfMonth),
              let to = cal.date(byAdding: .day, value: trailing, to: lastOfMonth)
        else { return }

        try await loadRange(from: from.isoDate, to: to.isoDate)
    }

    private func loadYearRange() async throws {
        let cal = Calendar.current
        let year = cal.component(.year, from: focusDate)
        let from = "\(year)-01-01"
        let to = "\(year)-12-31"
        try await loadRange(from: from, to: to)
    }

    private func loadRange(from: String, to: String) async throws {
        if loadedRanges.contains(where: { $0.from <= from && $0.to >= to }) { return }
        let resp = try await APIClient.shared.scheduleRange(from: from, to: to)
        // Clear the range first so dates that now have zero slots don't show stale data.
        slotsByDate = slotsByDate.filter { $0.key < from || $0.key > to }
        mergeSlots(resp.slots)
        loadedRanges.append((from, to))
    }

    private func mergeSlots(_ slots: [ScheduleSlot]) {
        let grouped = Dictionary(grouping: slots, by: { $0.date })
        for (date, daySlots) in grouped {
            slotsByDate[date] = daySlots.sorted { $0.datetime < $1.datetime }
        }
    }

    // MARK: - Slot mutations

    /// All mutations update local state optimistically first, then reconcile
    /// with the server response (or revert on failure). Keeps the UI feeling
    /// instant; the server remains the source of truth.

    func markDone(slot: ScheduleSlot) async {
        var optimistic = slot
        optimistic.status = .done
        replace(slot: optimistic)
        do {
            let updated = try await APIClient.shared.doneSlot(id: slot.id)
            replace(slot: updated)
        } catch {
            replace(slot: slot)
            self.error = error.localizedDescription
        }
    }

    func markSkip(slot: ScheduleSlot) async {
        var optimistic = slot
        optimistic.status = .skipped
        replace(slot: optimistic)
        do {
            let updated = try await APIClient.shared.skipSlot(id: slot.id)
            replace(slot: updated)
        } catch {
            replace(slot: slot)
            self.error = error.localizedDescription
        }
    }

    func assignTask(taskId: String, slotId: String) async {
        do {
            _ = try await APIClient.shared.assignTask(taskId: taskId, slotId: slotId)
            invalidateCache()
            await load()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func unassignTask(slot: ScheduleSlot) async {
        var optimistic = slot
        optimistic.taskId = nil
        optimistic.task = nil
        optimistic.status = .pending
        replace(slot: optimistic)
        do {
            let updated = try await APIClient.shared.unassignTask(slotId: slot.id)
            replace(slot: updated)
        } catch {
            replace(slot: slot)
            self.error = error.localizedDescription
        }
    }

    // MARK: - Navigation

    func stepWeek(by delta: Int) {
        focusDate = Calendar.current.date(byAdding: .weekOfYear, value: delta, to: focusDate) ?? focusDate
    }

    func stepDay(by delta: Int) {
        focusDate = Calendar.current.date(byAdding: .day, value: delta, to: focusDate) ?? focusDate
    }

    func stepMonth(by delta: Int) {
        focusDate = Calendar.current.date(byAdding: .month, value: delta, to: focusDate) ?? focusDate
    }

    func stepYear(by delta: Int) {
        focusDate = Calendar.current.date(byAdding: .year, value: delta, to: focusDate) ?? focusDate
    }

    /// Steps the current mode's period forward/backward by `delta`.
    func stepPeriod(by delta: Int) {
        switch mode {
        case .day:   stepDay(by: delta)
        case .month: stepMonth(by: delta)
        case .year:  stepYear(by: delta)
        }
    }

    func zoomIn(to mode: ScheduleViewMode, date: Date? = nil) {
        if let date { focusDate = date }
        self.mode = mode
    }

    private func replace(slot: ScheduleSlot) {
        var daySlots = slotsByDate[slot.date] ?? []
        if let idx = daySlots.firstIndex(where: { $0.id == slot.id }) {
            daySlots[idx] = slot
            slotsByDate[slot.date] = daySlots
        }
        // Keep weekResponse in sync so week-plan-level consumers see the change.
        if var slots = weekResponse?.slots,
           let idx = slots.firstIndex(where: { $0.id == slot.id }) {
            slots[idx] = slot
            weekResponse = WeekResponse(
                weekPlan: weekResponse?.weekPlan,
                slots: slots,
                allocations: weekResponse?.allocations ?? []
            )
        }
    }

    private func invalidateCache() {
        loadedRanges.removeAll()
    }
}
