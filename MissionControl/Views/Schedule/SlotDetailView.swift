import SwiftUI

struct SlotDetailView: View {
    let slot: ScheduleSlot
    let viewModel: ScheduleViewModel

    private var slotDate: Date {
        ISO8601DateFormatter.shared.date(from: slot.date) ?? viewModel.focusDate
    }

    var body: some View {
        List {
            Section {
                LabeledContent("Time", value: "\(slot.dayOfWeek) \(slot.time)")
                LabeledContent("Type", value: slot.typeLabel)
                LabeledContent("Status") {
                    HStack(spacing: 6) {
                        Image(systemName: slot.statusIcon)
                            .foregroundStyle(slot.statusColor)
                        Text(slot.status.capitalized)
                            .foregroundStyle(slot.statusColor)
                    }
                }
                if let note = slot.note {
                    LabeledContent("Note", value: note)
                }
            } header: {
                Text("Slot Info")
            }

            if let task = slot.task {
                Section("Assigned Task") {
                    NavigationLink(value: task) {
                        HStack {
                            Text(task.name)
                        }
                    }
                }
            }

            if slot.status == "pending" || slot.status == "in-progress" {
                Section("Actions") {
                    Button {
                        Task {
                            await viewModel.markDone(slot: slot)
                        }
                    } label: {
                        Label("Mark Done", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }

                    Button {
                        Task {
                            await viewModel.markSkip(slot: slot)
                        }
                    } label: {
                        Label("Skip Slot", systemImage: "forward.circle.fill")
                            .foregroundStyle(.orange)
                    }
                }
            }
        }
        .chatContext(.schedule(date: slotDate))
        .chatContextToolbar()
        .navigationDestination(for: MCTask.self) { task in
            TaskDetailView(taskId: task.id)
        }
    }
}
