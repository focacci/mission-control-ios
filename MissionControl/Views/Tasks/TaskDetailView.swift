import SwiftUI

struct TaskDetailView: View {
    let taskId: String
    @State private var viewModel = TaskDetailViewModel()
    @State private var showingEdit = false
    @State private var showingComplete = false
    @State private var showingBlock = false
    @State private var blockReason = ""
    @State private var showingAddRequirement = false
    @State private var newRequirement = ""
    @State private var showingAddAssignment = false
    @State private var newAssignmentTitle = ""
    @State private var newAssignmentInstructions = ""

    private var context: ChatContextKind? {
        viewModel.task.map { .task(id: $0.id, name: $0.name) }
    }

    var body: some View {
        Group {
            if let task = viewModel.task {
                ScrollView(.vertical) {
                    VStack(alignment: .leading, spacing: 20) {
                        TaskDetailHeader(task: task)

                        SectionCard(title: "Status", icon: "flag.fill") {
                            VStack(alignment: .leading, spacing: 12) {
                                Label(task.statusLabel, systemImage: task.statusIcon)
                                    .font(.subheadline)
                                    .foregroundStyle(task.statusColor)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(task.statusColor.opacity(0.15), in: Capsule())

                                if !task.isTerminal {
                                    TaskActionBar(
                                        task: task,
                                        isSaving: viewModel.isSaving,
                                        onStart:    { Task { await viewModel.startTask() } },
                                        onComplete: { showingComplete = true },
                                        onBlock:    { showingBlock = true }
                                    )
                                }
                            }
                        }

                        if let summary = task.summary, !summary.isEmpty {
                            SectionCard(title: "Summary", icon: "checkmark.seal.fill") {
                                Text(summary)
                                    .font(.body)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        if let objective = task.objective, !objective.isEmpty {
                            SectionCard(title: "Objective", icon: "target") {
                                Text(objective)
                                    .font(.body)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        RequirementsCard(
                            requirements: task.requirements ?? [],
                            isSaving: viewModel.isSaving,
                            onToggle: { id in Task { await viewModel.toggleRequirement(reqId: id) } },
                            onDelete: { id in Task { await viewModel.deleteRequirement(reqId: id) } },
                            onAdd: { showingAddRequirement = true }
                        )

                        AgentAssignmentsCard(
                            assignments: task.agentAssignments ?? [],
                            isSaving: viewModel.isSaving,
                            onDelete: { id in Task { await viewModel.deleteAgentAssignment(id: id) } },
                            onAdd: { showingAddAssignment = true }
                        )

                        ContextChatHistorySection(
                            contextType: "task",
                            contextId: task.id
                        )
                    }
                    .padding()
                    .containerRelativeFrame(.horizontal)
                }
                .refreshable { await viewModel.load(id: taskId) }
                .chatContextToolbar()
                .navigationDestination(for: Requirement.self) { req in
                    RequirementDetailView(requirement: req) { _ in
                        Task { await viewModel.load(id: taskId) }
                    }
                }
                .navigationDestination(for: AgentAssignment.self) { aa in
                    AgentAssignmentDetailView(assignment: aa) { _ in
                        Task { await viewModel.load(id: taskId) }
                    }
                }
                .toolbar {
                    ToolbarItemGroup(placement: .primaryAction) {
                        Menu {
                            Button {
                                showingEdit = true
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                        } label: {
                            Image(systemName: "ellipsis")
                        }
                    }
                }
                .sheet(isPresented: $showingEdit) {
                    TaskEditSheet(task: task) { body in
                        Task { await viewModel.update(id: taskId, body: body) }
                    }
                }
                .errorAlert(message: $viewModel.error)
            } else if let error = viewModel.error {
                ContentUnavailableView {
                    Label("Error", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(error)
                } actions: {
                    Button("Retry") { Task { await viewModel.load(id: taskId) } }
                        .buttonStyle(.borderedProminent)
                }
            } else {
                ProgressView("Loading…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task { await viewModel.load(id: taskId) }
        .chatContext(context)
        .sheet(isPresented: $showingComplete) {
            CompleteTaskSheet { summary in
                Task { await viewModel.completeTask(summary: summary) }
            }
        }
        .sheet(isPresented: $showingBlock) {
            BlockReasonSheet(reason: $blockReason) {
                let reason = blockReason
                blockReason = ""
                Task { await viewModel.blockTask(reason: reason) }
            }
        }
        .alert("Add Requirement", isPresented: $showingAddRequirement) {
            TextField("Description", text: $newRequirement)
            Button("Add") {
                let desc = newRequirement
                newRequirement = ""
                Task { await viewModel.addRequirement(description: desc) }
            }
            Button("Cancel", role: .cancel) { newRequirement = "" }
        }
        .sheet(isPresented: $showingAddAssignment) {
            AddAgentAssignmentSheet(
                title: $newAssignmentTitle,
                instructions: $newAssignmentInstructions
            ) {
                let title = newAssignmentTitle
                let instructions = newAssignmentInstructions
                newAssignmentTitle = ""
                newAssignmentInstructions = ""
                Task { await viewModel.addAgentAssignment(title: title, instructions: instructions) }
            }
        }
    }
}

// MARK: - Block Reason Sheet

struct BlockReasonSheet: View {
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

// MARK: - Add Agent Assignment Sheet

struct AddAgentAssignmentSheet: View {
    @Binding var title: String
    @Binding var instructions: String
    let onSave: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Title") {
                    TextField("Short title", text: $title)
                }
                Section {
                    TextEditor(text: $instructions)
                        .frame(minHeight: 140)
                } header: {
                    Text("Instructions")
                } footer: {
                    Text("What the agent should do when the assignment's slot runs.")
                }
            }
            .navigationTitle("New Agent Assignment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        onSave()
                        dismiss()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}
