import SwiftUI

struct HomeView: View {
    @State private var viewModel = HomeViewModel()
    @State private var rosaryState = RosaryState()
    @State private var dailyNote = DailyNote()
    @State private var showingNoteEditor = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    WeekBarView(
                        weekDates: viewModel.weekDates,
                        selectedDate: viewModel.selectedDate
                    )
                    .padding(.bottom, 8)

                    VStack(spacing: 16) {
                        RosaryCard(mystery: RosaryMystery.forDate(Date()),
                                   state: rosaryState)

                        DailyNoteCard(note: dailyNote, showEditor: $showingNoteEditor)

                        TodayTasksCard(slots: viewModel.todayTaskSlots, viewModel: viewModel)
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle(Date().formatted(.dateTime.weekday(.wide).month().day()))
            .navigationBarTitleDisplayMode(.inline)
            .refreshable { await viewModel.load() }
            .errorAlert(message: $viewModel.error)
            .task { await viewModel.load() }
            .fullScreenCover(isPresented: $showingNoteEditor) {
                DailyNoteEditorView(note: dailyNote)
            }
        }
    }
}

// MARK: - Daily Note Card

private struct DailyNoteCard: View {
    let note: DailyNote
    @Binding var showEditor: Bool

    var body: some View {
        Button { showEditor = true } label: {
            VStack(alignment: .leading, spacing: 8) {
                Label("Daily Note", systemImage: "note.text")
                    .font(.headline)
                    .foregroundStyle(.primary)

                if note.text.isEmpty {
                    Text("Tap to write today's note…")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    Text(note.text)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Today Tasks Card

private struct TodayTasksCard: View {
    let slots: [ScheduleSlot]
    let viewModel: HomeViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Today's Tasks", systemImage: "checklist")
                .font(.headline)
                .padding(.horizontal, 4)

            if slots.isEmpty {
                Text("No tasks scheduled today")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 12)
            } else {
                ForEach(slots) { slot in
                    NavigationLink(value: slot) {
                        HomeSlotRow(slot: slot)
                    }
                    .buttonStyle(.plain)
                    .swipeActions(edge: .trailing) {
                        Button {
                            Task { await viewModel.doneSlot(slot) }
                        } label: {
                            Label("Done", systemImage: "checkmark")
                        }
                        .tint(.green)

                        Button {
                            Task { await viewModel.skipSlot(slot) }
                        } label: {
                            Label("Skip", systemImage: "forward")
                        }
                        .tint(.orange)
                    }
                }
            }
        }
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .navigationDestination(for: ScheduleSlot.self) { slot in
            if let taskId = slot.taskId {
                TaskDetailView(taskId: taskId)
            }
        }
    }
}

// MARK: - Home Slot Row

struct HomeSlotRow: View {
    let slot: ScheduleSlot

    var body: some View {
        HStack(spacing: 12) {
            Text(slot.time)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 42, alignment: .leading)

            Image(systemName: slot.statusIcon)
                .foregroundStyle(slot.statusColor)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 2) {
                Text(slot.typeLabel)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(slot.isDimmed ? .secondary : .primary)

                if let task = slot.task {
                    Text(task.objective ?? "")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()
        }
        .padding(.vertical, 4)
        .opacity(slot.status == "skipped" ? 0.4 : 1)
    }
}

// MARK: - Daily Note Editor

struct DailyNoteEditorView: View {
    let note: DailyNote
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            TextEditor(text: Binding(
                get: { note.text },
                set: { note.text = $0 }
            ))
            .font(.body)
            .padding(12)
            .navigationTitle(note.date)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
