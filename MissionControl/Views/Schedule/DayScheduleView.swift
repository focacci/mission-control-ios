import SwiftUI

struct DayScheduleView: View {
    let viewModel: ScheduleViewModel

    var taskSlots: [ScheduleSlot] {
        viewModel.slotsForFocusDate.filter { $0.type != "maintenance" }
    }

    var body: some View {
        if taskSlots.isEmpty {
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
                ForEach(taskSlots) { slot in
                    NavigationLink(value: slot) {
                        SlotRow(slot: slot)
                    }
                    .listRowBackground(Color.clear)
                    .swipeActions(edge: .trailing) {
                        slotActions(slot: slot)
                    }
                }
            }
            .listStyle(.plain)
        }
    }

    @ViewBuilder
    private func slotActions(slot: ScheduleSlot) -> some View {
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
