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
                        Text(slot.status.displayName)
                            .foregroundStyle(slot.statusColor)
                    }
                }
                if let note = slot.note {
                    LabeledContent("Note", value: note)
                }
            } header: {
                Text("Slot Info")
            }

            if let aa = slot.agentAssignment {
                Section("Assigned Agent Assignment") {
                    NavigationLink(value: aa) {
                        HStack(spacing: 10) {
                            AgentAssignmentStatusIcon(assignment: aa)
                            Text(aa.title)
                        }
                    }
                }
            }

            if let outputs = slot.outputs, !outputs.isEmpty {
                Section("Outputs") {
                    ForEach(outputs) { output in
                        HStack(spacing: 10) {
                            Image(systemName: output.kind.icon)
                                .foregroundStyle(output.kind.color)
                            if let urlStr = output.url, let url = URL(string: urlStr) {
                                Link(output.label, destination: url)
                            } else {
                                Text(output.label)
                            }
                            Spacer()
                            Text(output.kind.label)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            if slot.status == .pending || slot.status == .inProgress {
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
        .chatContext(.schedule(date: slotDate, mode: .day))
        .chatContextToolbar()
        .navigationDestination(for: AgentAssignment.self) { aa in
            AgentAssignmentDetailView(assignment: aa)
        }
        .navigationDestination(for: AgentOutput.self) { output in
            AgentOutputDetailView(output: output)
        }
    }
}
