import SwiftUI

struct GoalDetailView: View {
    let goalId: String
    @State private var viewModel = GoalDetailViewModel()
    @State private var showingEdit = false
    @State private var showingAddInitiative = false
    @State private var showingDeleteConfirm = false
    @Environment(\.dismiss) private var dismiss

    private var context: ChatContextKind? {
        viewModel.goal.map { .goal(id: $0.id, emoji: $0.emoji, name: $0.name) }
    }

    var body: some View {
        Group {
            if viewModel.goal == nil && viewModel.error == nil {
                ProgressView("Loading…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let goal = viewModel.goal {
                ScrollView(.vertical) {
                    VStack(alignment: .leading, spacing: 20) {
                        // Header
                        GoalDetailHeader(goal: goal)

                        // Initiatives
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Initiatives")
                                    .font(.headline)
                                Spacer()
                                Button {
                                    showingAddInitiative = true
                                } label: {
                                    Image(systemName: "plus.circle.fill")
                                        .foregroundStyle(.blue)
                                }
                            }
                            .padding(.horizontal, 4)

                            if let initiatives = goal.initiatives, !initiatives.isEmpty {
                                ForEach(initiatives) { initiative in
                                    NavigationLink(value: initiative) {
                                        InitiativeCard(initiative: initiative)
                                    }
                                    .buttonStyle(.plain)
                                    .contextMenu {
                                        Button(role: .destructive) {
                                            Task { await viewModel.deleteInitiative(id: initiative.id) }
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
                                }
                            } else {
                                Text("No initiatives yet")
                                    .foregroundStyle(.secondary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 20)
                                    .padding()
                                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                            }
                        }

                        // Past chats scoped to this goal
                        ContextChatHistorySection(
                            contextType: "goal",
                            contextId: goal.id
                        )
                    }
                    .padding()
                    .containerRelativeFrame(.horizontal)
                }
                .refreshable { await viewModel.load(id: goalId) }
                .chatContextToolbar()
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
                    GoalEditSheet(goal: goal) { body in
                        Task { await viewModel.update(id: goalId, body: body) }
                    }
                }
                .sheet(isPresented: $showingAddInitiative) {
                    AddInitiativeSheet { emoji, name, mission in
                        Task { await viewModel.createInitiative(emoji: emoji, name: name, mission: mission) }
                    }
                }
                .alert("Delete Goal?", isPresented: $showingDeleteConfirm) {
                    Button("Cancel", role: .cancel) {}
                    Button("Delete", role: .destructive) {
                        Task {
                            if await viewModel.deleteGoal(id: goalId) {
                                dismiss()
                            }
                        }
                    }
                } message: {
                    Text("This will permanently delete \"\(goal.name)\" and all of its initiatives and tasks.")
                }
                .errorAlert(message: $viewModel.error)
            } else if let error = viewModel.error {
                ContentUnavailableView {
                    Label("Error", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(error)
                } actions: {
                    Button("Retry") { Task { await viewModel.load(id: goalId) } }
                        .buttonStyle(.borderedProminent)
                }
            }
        }
        .task { await viewModel.load(id: goalId) }
        .chatContext(context)
    }
}

// MARK: - Add Initiative Sheet

struct AddInitiativeSheet: View {
    let onSave: (String, String, String?) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var emoji = ""
    @State private var name = ""
    @State private var mission = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Initiative Info") {
                    HStack {
                        Text("Emoji")
                        Spacer()
                        TextField("🚀", text: $emoji)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 50)
                    }
                    TextField("Initiative name", text: $name)
                }
                Section("Mission") {
                    TextEditor(text: $mission)
                        .frame(minHeight: 60)
                }
            }
            .navigationTitle("New Initiative")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        onSave(
                            emoji.isEmpty ? "🚀" : emoji,
                            name,
                            mission.isEmpty ? nil : mission
                        )
                        dismiss()
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
    }
}
