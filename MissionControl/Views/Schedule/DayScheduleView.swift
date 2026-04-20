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
    let viewModel: ScheduleViewModel
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
        let slots = viewModel.slotsForFocusDate
        if slots.isEmpty {
            VStack(spacing: 8) {
                Image(systemName: "calendar")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
                Text("Nothing scheduled")
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
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
                            let isAssignable = slot.taskId == nil && (slot.type == "flex" || slot.type == "task")
                            if slot.taskId != nil {
                                NavigationLink(value: slot) {
                                    SlotRow(slot: slot)
                                }
                                .listRowBackground(Color.clear)
                                .swipeActions(edge: .trailing) {
                                    slotActions(slot: slot)
                                }
                            } else if isAssignable {
                                Button { onAssignToSlot(slot) } label: {
                                    SlotRow(slot: slot)
                                        .frame(maxWidth: .infinity)
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .listRowBackground(Color.clear)
                            } else {
                                NavigationLink(value: slot) {
                                    SlotRow(slot: slot)
                                }
                                .listRowBackground(Color.clear)
                            }
                        }
                    }
                }
                .listStyle(.plain)
                .contentMargins(.bottom, 90, for: .scrollContent)
            }
        }
    }

    @ViewBuilder
    private func slotActions(slot: ScheduleSlot) -> some View {
        if slot.taskId != nil {
            Button {
                Task { await viewModel.unassignTask(slotId: slot.id) }
            } label: {
                Label("Unassign", systemImage: "minus.circle")
            }
            .tint(.red)
        }

        if slot.status != "done" {
            Button {
                Task { await viewModel.markDone(slot: slot) }
            } label: {
                Label("Done", systemImage: "checkmark")
            }
            .tint(.green)
        }

        if slot.status != "skipped" {
            Button {
                Task { await viewModel.markSkip(slot: slot) }
            } label: {
                Label("Skip", systemImage: "forward")
            }
            .tint(.orange)
        }
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
