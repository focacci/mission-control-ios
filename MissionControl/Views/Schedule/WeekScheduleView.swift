import SwiftUI

struct WeekScheduleView: View {
    let viewModel: ScheduleViewModel

    var body: some View {
        List {
            ForEach(viewModel.slotsByDay, id: \.date) { entry in
                let daySlots = entry.slots.filter { $0.type != "maintenance" }
                let isToday = entry.date.isoDate == Date().isoDate

                Section {
                    if daySlots.isEmpty {
                        Text("Nothing scheduled")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .listRowBackground(Color.clear)
                    } else {
                        ForEach(daySlots) { slot in
                            NavigationLink(value: slot) {
                                SlotRow(slot: slot)
                            }
                            .listRowBackground(Color.clear)
                            .swipeActions(edge: .trailing) {
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
                    }
                } header: {
                    HStack {
                        Text(entry.date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))
                            .font(.subheadline)
                            .fontWeight(isToday ? .bold : .regular)
                            .foregroundStyle(isToday ? Color.accentColor : .secondary)

                        if isToday {
                            Text("TODAY")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.accentColor, in: Capsule())
                        }

                        Spacer()

                        let done = entry.slots.filter { $0.status == "done" }.count
                        let total = entry.slots.filter { $0.type == "task" }.count
                        if total > 0 {
                            Text("\(done)/\(total)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }
}
