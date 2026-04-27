import SwiftUI

struct TaskDetailView: View {
    let taskId: String
    @State private var viewModel = TaskDetailViewModel()
    @State private var showingEdit = false
    @State private var showingComplete = false
    @State private var showingAddRequirement = false
    @State private var newRequirement = ""
    @State private var showingAddAssignment = false
    @State private var newAssignmentTitle = ""
    @State private var newAssignmentDescription = ""
    @State private var showingDeleteConfirm = false
    @Environment(\.dismiss) private var dismiss

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

                                TaskActionBar(
                                    task: task,
                                    isSaving: viewModel.isSaving,
                                    onComplete: { showingComplete = true },
                                    onReopen: { Task { await viewModel.reopenTask() } }
                                )
                            }
                        }

                        if let summary = task.summary, !summary.isEmpty {
                            SectionCard(title: "Summary", icon: "checkmark.seal.fill") {
                                Text(summary)
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
                .conditionalRefreshable { await viewModel.load(id: taskId) }
                .chatContextToolbar()
                .navigationDestination(for: Requirement.self) { req in
                    RequirementDetailView(
                        requirement: req,
                        onChange: { _ in
                            Task { await viewModel.load(id: taskId) }
                        },
                        onDelete: { _ in
                            Task { await viewModel.load(id: taskId) }
                        }
                    )
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
                            Button(role: .destructive) {
                                showingDeleteConfirm = true
                            } label: {
                                Label("Delete", systemImage: "trash")
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
                .alert("Delete Task?", isPresented: $showingDeleteConfirm) {
                    Button("Cancel", role: .cancel) {}
                    Button("Delete", role: .destructive) {
                        Task {
                            if await viewModel.deleteTask(id: taskId) {
                                dismiss()
                            }
                        }
                    }
                } message: {
                    Text("This will permanently delete \"\(task.name)\".")
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
                description: $newAssignmentDescription
            ) {
                let title = newAssignmentTitle
                let description = newAssignmentDescription
                newAssignmentTitle = ""
                newAssignmentDescription = ""
                let normalized = description.isEmpty ? nil : description
                Task { await viewModel.addAgentAssignment(title: title, description: normalized) }
            }
        }
    }
}

// MARK: - Add Agent Assignment Sheet

struct AddAgentAssignmentSheet: View {
    @Binding var title: String
    @Binding var description: String
    let onSave: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Title") {
                    TextField("Short title", text: $title)
                }
                Section {
                    TextEditor(text: $description)
                        .frame(minHeight: 140)
                } header: {
                    Text("Description")
                } footer: {
                    Text("Optional context for the agent when this assignment's slot runs.")
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
