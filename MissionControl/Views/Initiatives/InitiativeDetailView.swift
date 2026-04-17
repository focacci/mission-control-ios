import SwiftUI

struct InitiativeDetailView: View {
    let initiativeId: String
    @State private var viewModel = InitiativeDetailViewModel()
    @State private var showingEdit = false
    @State private var showingAddTask = false
    @State private var blockingTaskId: String?
    @State private var blockReason = ""
    @State private var showingBlockSheet = false

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.initiative == nil {
                ProgressView("Loading…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let initiative = viewModel.initiative {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Header
                        InitiativeDetailHeader(initiative: initiative)

                        // Tasks
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Tasks")
                                    .font(.headline)
                                Spacer()
                                Button {
                                    showingAddTask = true
                                } label: {
                                    Image(systemName: "plus.circle.fill")
                                        .foregroundStyle(.blue)
                                }
                            }
                            .padding(.horizontal, 4)

                            if !viewModel.inProgressTasks.isEmpty {
                                TaskSection(
                                    title: "In Progress",
                                    tasks: viewModel.inProgressTasks,
                                    viewModel: viewModel,
                                    onBlock: { id in
                                        blockingTaskId = id
                                        showingBlockSheet = true
                                    }
                                )
                            }

                            if !viewModel.blockedTasks.isEmpty {
                                TaskSection(
                                    title: "Blocked",
                                    tasks: viewModel.blockedTasks,
                                    viewModel: viewModel,
                                    onBlock: nil
                                )
                            }

                            if !viewModel.activeTasks.isEmpty {
                                TaskSection(
                                    title: "Pending / Assigned",
                                    tasks: viewModel.activeTasks,
                                    viewModel: viewModel,
                                    onBlock: nil
                                )
                            }

                            if !viewModel.doneTasks.isEmpty {
                                TaskSection(
                                    title: "Completed",
                                    tasks: viewModel.doneTasks,
                                    viewModel: viewModel,
                                    onBlock: nil
                                )
                            }

                            if viewModel.tasks.isEmpty {
                                Text("No tasks yet")
                                    .foregroundStyle(.secondary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 20)
                                    .padding()
                                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                            }
                        }
                    }
                    .padding()
                }
                .refreshable { await viewModel.load(id: initiativeId) }
                .navigationTitle("Initiative")
                .navigationBarTitleDisplayMode(.large)
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button("Edit") { showingEdit = true }
                    }
                }
                .sheet(isPresented: $showingEdit) {
                    InitiativeEditSheet(initiative: initiative) { body in
                        Task { await viewModel.update(id: initiativeId, body: body) }
                    }
                }
                .sheet(isPresented: $showingAddTask) {
                    AddTaskSheet { name, objective, emoji in
                        Task { await viewModel.createTask(name: name, objective: objective, emoji: emoji) }
                    }
                }
                .sheet(isPresented: $showingBlockSheet) {
                    BlockTaskSheet(reason: $blockReason) {
                        if let id = blockingTaskId {
                            Task { await viewModel.blockTask(id: id, reason: blockReason) }
                        }
                        blockReason = ""
                        blockingTaskId = nil
                    }
                }
            } else if let error = viewModel.error {
                ContentUnavailableView {
                    Label("Error", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(error)
                } actions: {
                    Button("Retry") { Task { await viewModel.load(id: initiativeId) } }
                        .buttonStyle(.borderedProminent)
                }
            }
        }
        .task { await viewModel.load(id: initiativeId) }
    }
}

// MARK: - Initiative Detail Header

struct InitiativeDetailHeader: View {
    let initiative: Initiative

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text(initiative.emoji)
                    .font(.system(size: 56))

                Text(initiative.name)
                    .font(.title2)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.leading)

                Spacer()
            }

            HStack(spacing: 12) {
                Label(initiative.statusLabel, systemImage: initiative.statusIcon)
                    .font(.subheadline)
                    .foregroundStyle(initiative.statusColor)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(initiative.statusColor.opacity(0.15), in: Capsule())

                Spacer()
            }

            if let mission = initiative.mission, !mission.isEmpty {
                Text(mission)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Task Section

struct TaskSection: View {
    let title: String
    let tasks: [MCTask]
    let viewModel: InitiativeDetailViewModel
    let onBlock: ((String) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .padding(.horizontal, 4)

            VStack(spacing: 2) {
                ForEach(tasks) { task in
                    NavigationLink(value: task) {
                        TaskRow(task: task)
                    }
                    .buttonStyle(.plain)
                    .swipeActions(edge: .leading, allowsFullSwipe: false) {
                        if task.canStart {
                            Button {
                                Task { await viewModel.startTask(id: task.id) }
                            } label: {
                                Label("Start", systemImage: "play.fill")
                            }
                            .tint(.blue)
                        }
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            Task { await viewModel.cancelTask(id: task.id) }
                        } label: {
                            Label("Cancel", systemImage: "xmark")
                        }

                        if let onBlock, task.canBlock {
                            Button {
                                onBlock(task.id)
                            } label: {
                                Label("Block", systemImage: "exclamationmark.circle")
                            }
                            .tint(.orange)
                        }
                    }
                }
            }
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        }
    }
}

// MARK: - Block Task Sheet

struct BlockTaskSheet: View {
    @Binding var reason: String
    let onBlock: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Block Reason") {
                    TextEditor(text: $reason)
                        .frame(minHeight: 80)
                }
            }
            .navigationTitle("Block Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Block") {
                        onBlock()
                        dismiss()
                    }
                    .disabled(reason.isEmpty)
                }
            }
        }
    }
}

// MARK: - Add Task Sheet

struct AddTaskSheet: View {
    let onSave: (String, String, String?) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var emoji = ""
    @State private var name = ""
    @State private var objective = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Task Info") {
                    HStack {
                        Text("Emoji")
                        Spacer()
                        TextField("📋", text: $emoji)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 50)
                    }
                    TextField("Task name", text: $name)
                }
                Section("Objective") {
                    TextEditor(text: $objective)
                        .frame(minHeight: 80)
                }
            }
            .navigationTitle("New Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        onSave(
                            name,
                            objective,
                            emoji.isEmpty ? nil : emoji
                        )
                        dismiss()
                    }
                    .disabled(name.isEmpty || objective.isEmpty)
                }
            }
        }
    }
}
