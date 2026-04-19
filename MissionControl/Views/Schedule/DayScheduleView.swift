import SwiftUI

struct DayScheduleView: View {
    let viewModel: ScheduleViewModel
    let onAssignToSlot: (ScheduleSlot) -> Void

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
            List {
                ForEach(slots) { slot in
                    let isAssignable = slot.taskId == nil && (slot.type == "flex" || slot.type == "task")
                    if slot.taskId != nil {
                        // Filled task slot — navigate to task, swipe to unassign/done/skip
                        NavigationLink(value: slot) {
                            SlotRow(slot: slot)
                        }
                        .listRowBackground(Color.clear)
                        .swipeActions(edge: .trailing) {
                            slotActions(slot: slot)
                        }
                    } else if isAssignable {
                        // Empty assignable slot — tap to open task assignment sheet
                        Button { onAssignToSlot(slot) } label: {
                            SlotRow(slot: slot)
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(Color.clear)
                    } else {
                        // Fixed slot (brief, planning, maintenance)
                        NavigationLink(value: slot) {
                            SlotRow(slot: slot)
                        }
                        .listRowBackground(Color.clear)
                    }
                }
            }
            .listStyle(.plain)
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
