import SwiftUI

private enum ListItem: Identifiable {
    case slot(ScheduleSlot)
    case currentTimeMarker

    var id: String {
        switch self {
        case .slot(let s): return s.id
        case .currentTimeMarker: return "__current_time__"
        }
    }
}

struct DayScheduleView: View {
    @Bindable var viewModel: ScheduleViewModel
    let onAssignToSlot: (ScheduleSlot) -> Void

    private var isToday: Bool {
        Calendar.current.isDateInToday(viewModel.focusDate)
    }

    private func minutesSinceMidnight(_ date: Date) -> Int {
        let cal = Calendar.current
        return cal.component(.hour, from: date) * 60 + cal.component(.minute, from: date)
    }

    private func slotMinutes(_ slot: ScheduleSlot) -> Int {
        let parts = slot.time.split(separator: ":").compactMap { Int($0) }
        guard parts.count == 2 else { return 0 }
        return parts[0] * 60 + parts[1]
    }

    private func listItems(slots: [ScheduleSlot], now: Date) -> [ListItem] {
        guard isToday else { return slots.map { .slot($0) } }
        let nowMin = minutesSinceMidnight(now)
        var items: [ListItem] = []
        var inserted = false
        for slot in slots {
            if !inserted && nowMin < slotMinutes(slot) {
                items.append(.currentTimeMarker)
                inserted = true
            }
            items.append(.slot(slot))
        }
        if !inserted { items.append(.currentTimeMarker) }
        return items
    }

    var body: some View {
        VStack(spacing: 0) {
            WeekBar(
                weekDates: viewModel.weekDates,
                focusDate: $viewModel.focusDate,
                onPrev: { viewModel.stepWeek(by: -1) },
                onNext: { viewModel.stepWeek(by: 1) }
            )
            .padding(.bottom, 6)

            timeline
        }
    }

    /// Shown when the focused day has no slots — a static hourly skeleton so
    /// the UI still looks like a day view (not an error screen). Tapping any
    /// placeholder opens the scheduler sheet, which will generate the real
    /// week plan on demand.
    private func placeholderSlots(for date: Date) -> [ScheduleSlot] {
        let isoDate = date.isoDate
        let dayOfWeek = date.formatted(.dateTime.weekday(.wide))
        return (7...22).map { hour in
            let time = String(format: "%02d:00", hour)
            return ScheduleSlot(
                id: "placeholder-\(isoDate)-\(time)",
                weekPlanId: "",
                date: isoDate,
                time: time,
                datetime: "\(isoDate)T\(time):00",
                type: .flex,
                status: .pending,
                taskId: nil,
                goalId: nil,
                note: nil,
                dayOfWeek: dayOfWeek,
                task: nil
            )
        }
    }

    @ViewBuilder
    private var timeline: some View {
        let real = viewModel.slotsForFocusDate
        let slots = real.isEmpty ? placeholderSlots(for: viewModel.focusDate) : real
        TimelineView(.everyMinute) { context in
                List {
                    ForEach(listItems(slots: slots, now: context.date)) { item in
                        switch item {
                        case .currentTimeMarker:
                            CurrentTimeMarkerRow(time: context.date)
                                .listRowBackground(Color.clear)
                                .listRowInsets(.init(top: 0, leading: 0, bottom: 0, trailing: 0))
                                .listRowSeparator(.hidden)
                        case .slot(let slot):
                            let isAssignable = slot.isOpenSlot
                            if slot.taskId != nil {
                                NavigationLink(value: slot) {
                                    SlotCard(slot: slot)
                                }
                                .buttonStyle(.plain)
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                                .swipeActions(edge: .trailing) {
                                    slotActions(slot: slot)
                                }
                            } else if isAssignable {
                                Button { onAssignToSlot(slot) } label: {
                                    SlotCard(slot: slot)
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                            } else {
                                NavigationLink(value: slot) {
                                    SlotCard(slot: slot)
                                }
                                .buttonStyle(.plain)
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                            }
                        }
                    }
                }
                .listStyle(.plain)
                .contentMargins(.bottom, 90, for: .scrollContent)
            }
    }

    @ViewBuilder
    private func slotActions(slot: ScheduleSlot) -> some View {
        if slot.taskId != nil {
            Button {
                Task { await viewModel.unassignTask(slot: slot) }
            } label: {
                Label("Unassign", systemImage: "minus.circle")
            }
            .tint(.red)
        }

        if slot.status != .done {
            Button {
                Task { await viewModel.markDone(slot: slot) }
            } label: {
                Label("Done", systemImage: "checkmark")
            }
            .tint(.green)
        }

        if slot.status != .skipped {
            Button {
                Task { await viewModel.markSkip(slot: slot) }
            } label: {
                Label("Skip", systemImage: "forward")
            }
            .tint(.orange)
        }
    }
}

// MARK: - Fine-navigation week bar (Sun–Sat with chevrons)

private struct WeekBar: View {
    let weekDates: [Date]
    @Binding var focusDate: Date
    let onPrev: () -> Void
    let onNext: () -> Void

    private let dayLetters = ["S", "M", "T", "W", "T", "F", "S"]
    private let todayISO = Date().isoDate

    var body: some View {
        HStack(spacing: 0) {
            chevron("chevron.left", action: onPrev)

            ForEach(Array(weekDates.enumerated()), id: \.offset) { index, date in
                let iso = date.isoDate
                let isToday = iso == todayISO
                let isSelected = iso == focusDate.isoDate

                VStack(spacing: 3) {
                    Text(dayLetters[index])
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(isToday ? Color.accentColor : .secondary)

                    Text("\(Calendar.current.component(.day, from: date))")
                        .font(.system(size: 13, weight: isSelected ? .bold : .regular))
                        .foregroundStyle(isSelected ? .white : (isToday ? Color.accentColor : .primary))
                        .frame(width: 28, height: 28)
                        .background {
                            if isSelected {
                                Circle().fill(Color.accentColor)
                            } else if isToday {
                                Circle().strokeBorder(Color.accentColor, lineWidth: 1.5)
                            }
                        }
                }
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
                .onTapGesture { focusDate = date }
            }

            chevron("chevron.right", action: onNext)
        }
        .padding(.horizontal, 4)
    }

    @ViewBuilder
    private func chevron(_ systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 12, weight: .semibold))
                .frame(width: 32, height: 40)
                .contentShape(Rectangle())
        }
        .foregroundStyle(.secondary)
        .buttonStyle(.plain)
    }
}

private struct CurrentTimeMarkerRow: View {
    let time: Date

    private var label: String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: time)
    }

    var body: some View {
        HStack(spacing: 0) {
            Text(label)
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(.red)
                .frame(width: 42, alignment: .leading)
                .padding(.leading, 16)
            Circle()
                .fill(Color.red)
                .frame(width: 7, height: 7)
            Rectangle()
                .fill(Color.red)
                .frame(height: 1)
        }
        .padding(.vertical, 1)
    }
}
