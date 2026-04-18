import SwiftUI

struct ScheduleTaskSheet: View {
    @Environment(\.dismiss) private var dismiss

    private let preselectedTask: MCTask?
    private let preselectedSlot: ScheduleSlot?
    private let onAssigned: (() -> Void)?

    @State private var tasks: [MCTask] = []
    @State private var selectedTask: MCTask?
    @State private var selectedDate: Date
    @State private var weekResponse: WeekResponse?
    @State private var selectedSlot: ScheduleSlot?
    @State private var isLoading = false
    @State private var isSaving = false
    @State private var error: String?

    init(
        preselectedTask: MCTask? = nil,
        targetDate: Date? = nil,
        preselectedSlot: ScheduleSlot? = nil,
        onAssigned: (() -> Void)? = nil
    ) {
        self.preselectedTask = preselectedTask
        self.preselectedSlot = preselectedSlot
        self.onAssigned = onAssigned

        let initialDate: Date
        if let d = targetDate {
            initialDate = d
        } else if let s = preselectedSlot?.date,
                  let d = ISO8601DateFormatter.shared.date(from: s) {
            initialDate = d
        } else {
            initialDate = Date()
        }
        _selectedDate = State(initialValue: initialDate)
        _selectedTask = State(initialValue: preselectedTask)
        _selectedSlot = State(initialValue: preselectedSlot)
    }

    private var weekStart: String {
        let cal = Calendar.current
        let weekday = cal.component(.weekday, from: selectedDate) - 1
        let sunday = cal.date(byAdding: .day, value: -weekday, to: selectedDate) ?? selectedDate
        return sunday.isoDate
    }

    private var availableSlots: [ScheduleSlot] {
        let dateISO = selectedDate.isoDate
        return (weekResponse?.slots ?? [])
            .filter {
                $0.date == dateISO
                    && $0.taskId == nil
                    && $0.type != "maintenance"
                    && $0.type != "planning"
                    && $0.type != "brief"
                    && $0.status != "done"
                    && $0.status != "skipped"
            }
            .sorted { $0.datetime < $1.datetime }
    }

    private var canAssign: Bool {
        selectedTask != nil && selectedSlot != nil && !isSaving
    }

    var body: some View {
        NavigationStack {
            Form {
                // Task section
                if let fixed = preselectedTask {
                    Section("Task") {
                        HStack(spacing: 8) {
                            Text(fixed.emoji ?? "📋")
                            Text(fixed.name)
                                .fontWeight(.medium)
                        }
                    }
                } else {
                    Section("Select Task") {
                        if isLoading && tasks.isEmpty {
                            HStack { Spacer(); ProgressView(); Spacer() }
                        } else if tasks.isEmpty {
                            Text("No pending tasks")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(tasks) { task in
                                TaskPickerRow(task: task, isSelected: selectedTask?.id == task.id) {
                                    selectedTask = task
                                }
                            }
                        }
                    }
                }

                // Date section
                Section("Date") {
                    DatePicker("", selection: $selectedDate, displayedComponents: .date)
                        .datePickerStyle(.compact)
                        .labelsHidden()
                        .onChange(of: selectedDate) { _, _ in
                            selectedSlot = nil
                            Task { await loadSlots() }
                        }
                }

                // Slots section
                Section("Available Slots") {
                    if isLoading {
                        HStack { Spacer(); ProgressView(); Spacer() }
                    } else if weekResponse == nil {
                        Text("No week plan for this date")
                            .foregroundStyle(.secondary)
                    } else if availableSlots.isEmpty {
                        Text("No open slots on this date")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(availableSlots) { slot in
                            SlotPickerRow(slot: slot, isSelected: selectedSlot?.id == slot.id) {
                                selectedSlot = slot
                            }
                        }
                    }
                }
            }
            .navigationTitle("Schedule Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSaving {
                        ProgressView()
                    } else {
                        Button("Assign") {
                            Task { await assign() }
                        }
                        .disabled(!canAssign)
                    }
                }
            }
        }
        .task {
            isLoading = true
            do {
                if preselectedTask == nil {
                    tasks = try await APIClient.shared.tasks(statuses: ["pending", "assigned"])
                }
                weekResponse = try await APIClient.shared.scheduleWeek(weekStart: weekStart)
            } catch APIError.serverError(let msg) where msg.lowercased().hasPrefix("no week plan") {
                weekResponse = nil
            } catch {
                self.error = error.localizedDescription
            }
            isLoading = false
        }
        .errorAlert(message: $error)
    }

    private func loadSlots() async {
        isLoading = true
        do {
            weekResponse = try await APIClient.shared.scheduleWeek(weekStart: weekStart)
        } catch APIError.serverError(let msg) where msg.lowercased().hasPrefix("no week plan") {
            weekResponse = nil
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    private func assign() async {
        guard let task = selectedTask, let slot = selectedSlot else { return }
        isSaving = true
        do {
            _ = try await APIClient.shared.assignTask(taskId: task.id, slotId: slot.id)
            onAssigned?()
            dismiss()
        } catch {
            self.error = error.localizedDescription
            isSaving = false
        }
    }
}

// MARK: - Task Picker Row

private struct TaskPickerRow: View {
    let task: MCTask
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 8) {
                Text(task.emoji ?? "📋")
                    .font(.body)

                VStack(alignment: .leading, spacing: 2) {
                    Text(task.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)

                    if let obj = task.objective, !obj.isEmpty {
                        Text(obj)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.tint)
                        .fontWeight(.semibold)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Slot Picker Row

private struct SlotPickerRow: View {
    let slot: ScheduleSlot
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Text(slot.time)
                    .font(.system(.subheadline, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .frame(width: 48, alignment: .leading)

                Text(slot.type == "task" ? "Task Slot" : "Open Slot")
                    .font(.subheadline)
                    .foregroundStyle(.primary)

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.tint)
                        .fontWeight(.semibold)
                }
            }
        }
        .buttonStyle(.plain)
    }
}
