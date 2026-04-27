import SwiftUI

struct ScheduleTaskSheet: View {
    @Environment(\.dismiss) private var dismiss

    private let preselectedTask: MCTask?
    private let preselectedSlot: ScheduleSlot?
    private let preselectedSlotId: String?
    private let onAssigned: (() -> Void)?

    @State private var goals: [Goal] = []
    @State private var selectedGoal: Goal?
    @State private var goalExpanded = true
    @State private var initiatives: [Initiative] = []
    @State private var selectedInitiative: Initiative?
    @State private var initiativeExpanded = true
    @State private var tasks: [MCTask] = []
    @State private var selectedTask: MCTask?
    @State private var assignments: [AgentAssignment] = []
    @State private var selectedAssignment: AgentAssignment?
    @State private var isLoadingAssignments = false
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
        preselectedSlotId: String? = nil,
        onAssigned: (() -> Void)? = nil
    ) {
        self.preselectedTask = preselectedTask
        self.preselectedSlot = preselectedSlot
        self.preselectedSlotId = preselectedSlotId
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
        let pinnedId = preselectedSlot?.id ?? preselectedSlotId
        return (weekResponse?.slots ?? [])
            .filter {
                $0.date == dateISO
                    && ($0.agentAssignmentId == nil || $0.id == pinnedId)
                    && $0.status != .done
                    && $0.status != .skipped
            }
            .sorted { $0.datetime < $1.datetime }
    }

    private var canAssign: Bool {
        selectedAssignment != nil && selectedSlot != nil && !isSaving
    }

    var body: some View {
        NavigationStack {
            Form {
                // Task section — fixed when preselected, otherwise tree picker
                if let fixed = preselectedTask {
                    Section("Task") {
                        HStack(spacing: 8) {
                            Text(fixed.name)
                                .fontWeight(.medium)
                        }
                    }
                } else {
                    // Step 1: Goal
                    Section {
                        if isLoading && goals.isEmpty {
                            HStack { Spacer(); ProgressView(); Spacer() }
                        } else if goals.isEmpty {
                            Text("No goals available")
                                .foregroundStyle(.secondary)
                        } else if let sg = selectedGoal, !goalExpanded {
                            GoalPickerRow(goal: sg, isSelected: true) {
                                withAnimation(.easeInOut(duration: 0.25)) {
                                    selectedGoal = nil
                                    selectedInitiative = nil
                                    selectedTask = nil
                                    initiatives = []
                                    tasks = []
                                    goalExpanded = true
                                    initiativeExpanded = true
                                }
                            }
                            .transition(.opacity)
                        } else {
                            ForEach(goals) { goal in
                                GoalPickerRow(goal: goal, isSelected: selectedGoal?.id == goal.id) {
                                    withAnimation(.easeInOut(duration: 0.25)) {
                                        selectedGoal = goal
                                        selectedInitiative = nil
                                        selectedTask = nil
                                        initiatives = []
                                        tasks = []
                                        goalExpanded = false
                                        initiativeExpanded = true
                                    }
                                    Task { await loadInitiatives(for: goal.id) }
                                }
                            }
                            .transition(.opacity)
                        }
                    } header: {
                        HStack {
                            Text("Goal")
                            if selectedGoal != nil && !goalExpanded {
                                Spacer()
                                Button("Change") {
                                    withAnimation(.easeInOut(duration: 0.25)) {
                                        goalExpanded = true
                                    }
                                }
                                .font(.caption)
                                .textCase(nil)
                            }
                        }
                    }

                    // Step 2: Initiative (revealed after goal selection)
                    if selectedGoal != nil {
                        Section {
                            if isLoadingInitiatives {
                                HStack { Spacer(); ProgressView(); Spacer() }
                            } else if initiatives.isEmpty {
                                Text("No open initiatives")
                                    .foregroundStyle(.secondary)
                            } else if let si = selectedInitiative, !initiativeExpanded {
                                InitiativePickerRow(initiative: si, isSelected: true) {
                                    withAnimation(.easeInOut(duration: 0.25)) {
                                        selectedInitiative = nil
                                        selectedTask = nil
                                        tasks = []
                                        initiativeExpanded = true
                                    }
                                }
                                .transition(.opacity)
                            } else {
                                ForEach(initiatives) { initiative in
                                    InitiativePickerRow(
                                        initiative: initiative,
                                        isSelected: selectedInitiative?.id == initiative.id
                                    ) {
                                        withAnimation(.easeInOut(duration: 0.25)) {
                                            selectedInitiative = initiative
                                            selectedTask = nil
                                            tasks = []
                                            initiativeExpanded = false
                                        }
                                        Task { await loadTasks(for: initiative.id) }
                                    }
                                }
                                .transition(.opacity)
                            }
                        } header: {
                            HStack {
                                Text("Initiative")
                                if selectedInitiative != nil && !initiativeExpanded {
                                    Spacer()
                                    Button("Change") {
                                        withAnimation(.easeInOut(duration: 0.25)) {
                                            initiativeExpanded = true
                                        }
                                    }
                                    .font(.caption)
                                    .textCase(nil)
                                }
                            }
                        }
                        .transition(.opacity)
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
                                        selectedAssignment = nil
                                        Task { await loadAssignments(for: task.id) }
                                    }
                                }
                            }
                        }
                        .transition(.opacity)
                    }
                }

                // Agent Assignment picker (always required — the thing actually scheduled)
                if selectedTask != nil {
                    Section("Agent Assignment") {
                        if isLoadingAssignments {
                            HStack { Spacer(); ProgressView(); Spacer() }
                        } else if assignments.isEmpty {
                            Text("No agent assignments on this task. Add one from the task detail first.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(assignments) { aa in
                                Button {
                                    selectedAssignment = selectedAssignment?.id == aa.id ? nil : aa
                                } label: {
                                    HStack(spacing: 10) {
                                        AgentAssignmentStatusIcon(assignment: aa)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(aa.title)
                                                .font(.subheadline)
                                                .foregroundStyle(selectedAssignment?.id == aa.id ? Color.accentColor : .primary)
                                            if let desc = aa.description, !desc.isEmpty {
                                                Text(desc)
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                                    .lineLimit(1)
                                            }
                                        }
                                        Spacer()
                                        if selectedAssignment?.id == aa.id {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundStyle(Color.accentColor)
                                        }
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .transition(.opacity)
                }

                // Day picker
                Section("Date") {
                    WeekDayStrip(selectedDate: $selectedDate)
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
                                selectedSlot = selectedSlot?.id == slot.id ? nil : slot
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
                statuses: ["pending"]
            )
        } catch {
            self.error = error.localizedDescription
        }
        isLoadingTasks = false
    }

    private func loadAssignments(for taskId: String) async {
        isLoadingAssignments = true
        assignments = []
        do {
            let all = try await APIClient.shared.agentAssignments(taskId: taskId)
            assignments = all.filter { !$0.isDone }
        } catch {
            self.error = error.localizedDescription
        }
        isLoadingAssignments = false
    }

    private func loadSlots() async {
        isLoading = true
        let savedSlotId = selectedSlot?.id ?? preselectedSlot?.id ?? preselectedSlotId
        selectedSlot = nil
        do {
            var response = try await APIClient.shared.scheduleWeek(weekStart: weekStart)
            if response.weekPlan == nil {
                response = try await APIClient.shared.generateWeekPlan(weekStart: weekStart)
            }
            weekResponse = response
            if let id = savedSlotId {
                selectedSlot = response.slots.first { $0.id == id }
            }
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    private func assign() async {
        guard let assignment = selectedAssignment, let slot = selectedSlot else { return }
        isSaving = true
        do {
            _ = try await APIClient.shared.assignAgentAssignment(
                agentAssignmentId: assignment.id, slotId: slot.id
            )
            onAssigned?()
            dismiss()
        } catch {
            self.error = error.localizedDescription
            isSaving = false
        }
    }

}

// MARK: - Week Day Strip

private struct WeekDayStrip: View {
    @Binding var selectedDate: Date

    private var weekDays: [Date] {
        let cal = Calendar.current
        let weekday = cal.component(.weekday, from: selectedDate) - 1
        let sunday = cal.date(byAdding: .day, value: -weekday, to: selectedDate) ?? selectedDate
        return (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: sunday) }
    }

    private func shiftWeek(by weeks: Int) {
        selectedDate = Calendar.current.date(byAdding: .weekOfYear, value: weeks, to: selectedDate) ?? selectedDate
    }

    var body: some View {
        HStack(spacing: 4) {
            Button { shiftWeek(by: -1) } label: {
                Image(systemName: "chevron.left")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 24)
            }
            .buttonStyle(.plain)

            HStack(spacing: 4) {
                ForEach(weekDays, id: \.self) { day in
                    DayCell(
                        date: day,
                        isSelected: Calendar.current.isDate(day, inSameDayAs: selectedDate)
                    )
                    .onTapGesture { selectedDate = day }
                }
            }

            Button { shiftWeek(by: 1) } label: {
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 24)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }
}

private struct DayCell: View {
    let date: Date
    let isSelected: Bool

    private static let dayLetterFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "E"
        return f
    }()

    private static let dayNumFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "d"
        return f
    }()

    private var dayLetter: String {
        String(Self.dayLetterFormatter.string(from: date).prefix(1))
    }

    private var dayNum: String {
        Self.dayNumFormatter.string(from: date)
    }

    private var isToday: Bool {
        Calendar.current.isDateInToday(date)
    }

    var body: some View {
        VStack(spacing: 3) {
            Text(dayLetter)
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundStyle(isSelected ? .white : .secondary)
            Text(dayNum)
                .font(.subheadline)
                .fontWeight(isSelected ? .bold : isToday ? .semibold : .regular)
                .foregroundStyle(isSelected ? .white : isToday ? Color.accentColor : .primary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(isSelected ? Color.accentColor : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(isToday && !isSelected ? Color.accentColor.opacity(0.4) : .clear, lineWidth: 1.5)
        )
    }
}

// MARK: - Goal Picker Row

private struct GoalPickerRow: View {
    let goal: Goal
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                Text(goal.emoji)

                VStack(alignment: .leading, spacing: 2) {
                    Text(goal.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(isSelected ? Color.accentColor : .primary)
                    if let icon = goal.focusIcon {
                        Text(icon + " " + goal.focusLabel)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.accentColor)
                        .font(.subheadline)
                }
            }
            .padding(.vertical, 2)
            .padding(.horizontal, 4)
            .background(isSelected ? Color.accentColor.opacity(0.08) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 8))
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
            HStack(spacing: 10) {
                Text(initiative.emoji)

                VStack(alignment: .leading, spacing: 2) {
                    Text(initiative.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(isSelected ? Color.accentColor : .primary)
                    Text(initiative.statusLabel)
                        .font(.caption)
                        .foregroundStyle(initiative.statusColor)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.accentColor)
                        .font(.subheadline)
                }
            }
            .padding(.vertical, 2)
            .padding(.horizontal, 4)
            .background(isSelected ? Color.accentColor.opacity(0.08) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 8))
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
            HStack(spacing: 10) {

                VStack(alignment: .leading, spacing: 2) {
                    Text(task.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(isSelected ? Color.accentColor : .primary)

                    if let obj = task.objective, !obj.isEmpty {
                        Text(obj)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.accentColor)
                        .font(.subheadline)
                }
            }
            .padding(.vertical, 2)
            .padding(.horizontal, 4)
            .background(isSelected ? Color.accentColor.opacity(0.08) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 8))
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
                    .foregroundStyle(isSelected ? Color.accentColor : .secondary)
                    .frame(width: 48, alignment: .leading)

                Text(slot.type == .agentAssignment ? "Agent Slot" : "Open Slot")
                    .font(.subheadline)
                    .foregroundStyle(isSelected ? Color.accentColor : .primary)
                    .fontWeight(isSelected ? .medium : .regular)

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.accentColor)
                        .font(.subheadline)
                }
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 4)
            .background(isSelected ? Color.accentColor.opacity(0.08) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }
}
