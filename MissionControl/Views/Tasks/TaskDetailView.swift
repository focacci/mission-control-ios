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
    @State private var showingAddTest = false
    @State private var newTest = ""

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.task == nil {
                ProgressView("Loading…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let task = viewModel.task {
                ScrollView {
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

                        // Summary (if done)
                        if let summary = task.summary, !summary.isEmpty {
                            SectionCard(title: "Summary", icon: "checkmark.seal.fill") {
                                Text(summary)
                                    .font(.body)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        // Objective
                        if let objective = task.objective, !objective.isEmpty {
                            SectionCard(title: "Objective", icon: "target") {
                                Text(objective)
                                    .font(.body)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        // Requirements
                        RequirementsCard(
                            requirements: task.requirements ?? [],
                            isSaving: viewModel.isSaving,
                            onToggle: { id in Task { await viewModel.toggleRequirement(reqId: id) } },
                            onDelete: { id in Task { await viewModel.deleteRequirement(reqId: id) } },
                            onAdd: { showingAddRequirement = true }
                        )

                        // Tests
                        TestsCard(
                            tests: task.tests ?? [],
                            onDelete: { id in Task { await viewModel.deleteTest(testId: id) } },
                            onAdd: { showingAddTest = true }
                        )

                        // Outputs
                        if let outputs = task.outputs, !outputs.isEmpty {
                            OutputsCard(outputs: outputs)
                        }
                    }
                    .padding()
                }
                .refreshable { await viewModel.load(id: taskId) }
                .navigationTitle("Task")
                .navigationBarTitleDisplayMode(.large)
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button("Edit") { showingEdit = true }
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
            }
        }
        .task { await viewModel.load(id: taskId) }
        .sheet(isPresented: $showingComplete) {
            CompleteTaskSheet { summary in
                Task { await viewModel.completeTask(summary: summary) }
            }
        }
        .sheet(isPresented: $showingBlock) {
            BlockReasonSheet(reason: $blockReason) {
                Task { await viewModel.blockTask(reason: blockReason) }
                blockReason = ""
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
        .alert("Add Test", isPresented: $showingAddTest) {
            TextField("Description", text: $newTest)
            Button("Add") {
                let desc = newTest
                newTest = ""
                Task { await viewModel.addTest(description: desc) }
            }
            Button("Cancel", role: .cancel) { newTest = "" }
        }
    }
}

// MARK: - Task Detail Header

struct TaskDetailHeader: View {
    let task: MCTask

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(task.name)
                .font(.title2)
                .fontWeight(.bold)
                .multilineTextAlignment(.leading)

            if task.goal != nil || task.initiative != nil {
                HStack(spacing: 8) {
                    if let goal = task.goal {
                        Text("\(goal.emoji) \(goal.name)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(.clear, in: Capsule())
                            .overlay(Capsule().strokeBorder(.secondary.opacity(0.4), lineWidth: 1))
                    }

                    if let initiative = task.initiative {
                        Text("\(initiative.emoji) \(initiative.name)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(.clear, in: Capsule())
                            .overlay(Capsule().strokeBorder(.secondary.opacity(0.4), lineWidth: 1))
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Task Action Bar

struct TaskActionBar: View {
    let task: MCTask
    let isSaving: Bool
    let onStart: () -> Void
    let onComplete: () -> Void
    let onBlock: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            if task.canStart {
                Button(action: onStart) {
                    Label("Start", systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
                .disabled(isSaving)
            }

            if task.canComplete {
                Button(action: onComplete) {
                    Label("Complete", systemImage: "checkmark")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .disabled(isSaving)
            }

            if task.canBlock {
                Button(action: onBlock) {
                    Label("Block", systemImage: "exclamationmark.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.orange)
                .disabled(isSaving)
            }
        }
    }
}

// MARK: - Requirements Card

struct RequirementsCard: View {
    let requirements: [Requirement]
    let isSaving: Bool
    let onToggle: (String) -> Void
    let onDelete: (String) -> Void
    let onAdd: () -> Void

    var body: some View {
        SectionCard(title: "Requirements", icon: "checklist") {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(requirements) { req in
                    HStack(spacing: 10) {
                        Button {
                            onToggle(req.id)
                        } label: {
                            Image(systemName: req.completed ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(req.completed ? .green : .secondary)
                                .font(.title3)
                        }
                        .disabled(isSaving)

                        Text(req.description)
                            .font(.body)
                            .foregroundStyle(req.completed ? .secondary : .primary)
                            .strikethrough(req.completed)

                        Spacer()
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            onDelete(req.id)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }

                Button(action: onAdd) {
                    Label("Add Requirement", systemImage: "plus")
                        .font(.subheadline)
                        .foregroundStyle(.blue)
                }
                .padding(.top, requirements.isEmpty ? 0 : 4)
            }
        }
    }
}

// MARK: - Tests Card

struct TestsCard: View {
    let tests: [TaskTest]
    let onDelete: (String) -> Void
    let onAdd: () -> Void

    var body: some View {
        SectionCard(title: "Tests", icon: "checkmark.shield") {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(tests) { test in
                    HStack(spacing: 10) {
                        Image(systemName: test.passed ? "checkmark.shield.fill" : "shield")
                            .foregroundStyle(test.passed ? .green : .secondary)
                            .font(.title3)

                        Text(test.description)
                            .font(.body)

                        Spacer()
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            onDelete(test.id)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }

                Button(action: onAdd) {
                    Label("Add Test", systemImage: "plus")
                        .font(.subheadline)
                        .foregroundStyle(.blue)
                }
                .padding(.top, tests.isEmpty ? 0 : 4)
            }
        }
    }
}

// MARK: - Outputs Card

struct OutputsCard: View {
    let outputs: [TaskOutput]

    var body: some View {
        SectionCard(title: "Outputs", icon: "doc.fill") {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(outputs) { output in
                    HStack {
                        Image(systemName: "paperclip")
                            .foregroundStyle(.secondary)

                        if let urlStr = output.url, let url = URL(string: urlStr) {
                            Link(output.label, destination: url)
                                .font(.body)
                        } else {
                            Text(output.label)
                                .font(.body)
                        }

                        Spacer()
                    }
                }
            }
        }
    }
}

// MARK: - Section Card

struct SectionCard<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: icon)
                .font(.headline)

            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
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
