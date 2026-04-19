import SwiftUI

struct ScheduleTaskSheet: View {
    @Environment(\.dismiss) private var dismiss

    private let preselectedTask: MCTask?
    private let preselectedSlot: ScheduleSlot?
    private let onAssigned: (() -> Void)?

    @State private var goals: [Goal] = []
    @State private var selectedGoal: Goal?
    @State private var initiatives: [Initiative] = []
    @State private var selectedInitiative: Initiative?
    @State private var tasks: [MCTask] = []
    @State private var selectedTask: MCTask?
    @State private var selectedDate: Date
    @State private var weekResponse: WeekResponse?
    @State private var selectedSlot: ScheduleSlot?
    @State private var isLoading = false
    @State private var isLoadingInitiatives = false
    @State private var isLoadingTasks = false
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
                // Task section — fixed when preselected, otherwise tree picker
                if let fixed = preselectedTask {
                    Section("Task") {
                        HStack(spacing: 8) {
                            Text(fixed.emoji ?? "📋")
                            Text(fixed.name)
                                .fontWeight(.medium)
                        }
                    }
                } else {
                    // Step 1: Goal
                    Section("Goal") {
                        if isLoading && goals.isEmpty {
                            HStack { Spacer(); ProgressView(); Spacer() }
                        } else if goals.isEmpty {
                            Text("No goals available")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(goals) { goal in
                                GoalPickerRow(goal: goal, isSelected: selectedGoal?.id == goal.id) {
                                    guard selectedGoal?.id != goal.id else { return }
                                    selectedGoal = goal
                                    selectedInitiative = nil
                                    selectedTask = nil
                                    initiatives = []
                                    tasks = []
                                    Task { await loadInitiatives(for: goal.id) }
                                }
                            }
                        }
                    }

                    // Step 2: Initiative (revealed after goal selection)
                    if selectedGoal != nil {
                        Section("Initiative") {
                            if isLoadingInitiatives {
                                HStack { Spacer(); ProgressView(); Spacer() }
                            } else if initiatives.isEmpty {
                                Text("No open initiatives")
                                    .foregroundStyle(.secondary)
                            } else {
                                ForEach(initiatives) { initiative in
                                    InitiativePickerRow(
                                        initiative: initiative,
                                        isSelected: selectedInitiative?.id == initiative.id
                                    ) {
                                        guard selectedInitiative?.id != initiative.id else { return }
                                        selectedInitiative = initiative
                                        selectedTask = nil
                                        tasks = []
                                        Task { await loadTasks(for: initiative.id) }
                                    }
                                }
                            }
                        }
                    }

                    // Step 3: Task (revealed after initiative selection)
                    if selectedInitiative != nil {
                        Section("Task") {
                            if isLoadingTasks {
                                HStack { Spacer(); ProgressView(); Spacer() }
                            } else if tasks.isEmpty {
                                Text("No schedulable tasks")
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
                }

                // Week navigation
                Section("Week") {
                    DatePicker("", selection: $selectedDate, displayedComponents: .date)
                        .datePickerStyle(.compact)
                        .labelsHidden()
                        .onChange(of: selectedDate) { _, _ in
                            selectedSlot = nil
                            Task { await loadSlots() }
                        }
                }

                // Available slots for the selected day
                Section("Available Slots") {
                    if isLoading {
                        HStack { Spacer(); ProgressView(); Spacer() }
                    } else if availableSlots.isEmpty {
                        Text("No open slots on this day")
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
                    goals = try await APIClient.shared.goals()
                }
                await loadSlots()
            } catch {
                self.error = error.localizedDescription
                isLoading = false
            }
        }
        .errorAlert(message: $error)
    }

    private func loadInitiatives(for goalId: String) async {
        isLoadingInitiatives = true
        do {
            let all = try await APIClient.shared.initiatives(goalId: goalId)
            initiatives = all.filter { $0.status != "completed" }
        } catch {
            self.error = error.localizedDescription
        }
        isLoadingInitiatives = false
    }

    private func loadTasks(for initiativeId: String) async {
        isLoadingTasks = true
        do {
            tasks = try await APIClient.shared.tasks(
                initiativeId: initiativeId,
                statuses: ["pending", "assigned", "in-progress", "blocked"]
            )
        } catch {
            self.error = error.localizedDescription
        }
        isLoadingTasks = false
    }

    private func loadSlots() async {
        isLoading = true
        selectedSlot = nil
        do {
            var response = try await APIClient.shared.scheduleWeek(weekStart: weekStart)
            if response.weekPlan == nil {
                response = try await APIClient.shared.generateWeekPlan(weekStart: weekStart)
            }
            weekResponse = response
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

// MARK: - Goal Picker Row

private struct GoalPickerRow: View {
    let goal: Goal
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 8) {
                Text(goal.emoji)
                    .font(.body)

                VStack(alignment: .leading, spacing: 2) {
                    Text(goal.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)
                    if let icon = goal.focusIcon {
                        Text(icon + " " + goal.focusLabel)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                if isSelected {
                    Image(systemName: "chevron.right")
                        .foregroundStyle(.tint)
                        .fontWeight(.semibold)
                        .font(.caption)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Initiative Picker Row

private struct InitiativePickerRow: View {
    let initiative: Initiative
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 8) {
                Text(initiative.emoji)
                    .font(.body)

                VStack(alignment: .leading, spacing: 2) {
                    Text(initiative.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)
                    Text(initiative.statusLabel)
                        .font(.caption)
                        .foregroundStyle(initiative.statusColor)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "chevron.right")
                        .foregroundStyle(.tint)
                        .fontWeight(.semibold)
                        .font(.caption)
                }
            }
        }
        .buttonStyle(.plain)
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
