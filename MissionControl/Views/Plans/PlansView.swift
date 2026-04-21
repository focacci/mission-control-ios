import SwiftUI

enum PlanSection: String, CaseIterable {
    case goals = "Goals"
    case initiatives = "Initiatives"
    case tasks = "Tasks"
}

struct PlansView: View {
    @State private var viewModel = PlansViewModel()
    @State private var selectedSection: PlanSection = .goals
    @State private var showingAddGoal = false
    @State private var showingAddInitiative = false
    @State private var showingAddTask = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Section", selection: $selectedSection) {
                    ForEach(PlanSection.allCases, id: \.self) { section in
                        Text(section.rawValue).tag(section)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)

                Group {
                    if viewModel.isLoading && viewModel.goals.isEmpty && viewModel.initiatives.isEmpty && viewModel.tasks.isEmpty {
                        ProgressView("Loading…")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if let error = viewModel.error {
                        VStack(spacing: 12) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.largeTitle)
                                .foregroundStyle(.orange)
                            Text(error)
                                .multilineTextAlignment(.center)
                                .foregroundStyle(.secondary)
                            Button("Retry") {
                                Task { await viewModel.load() }
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        switch selectedSection {
                        case .goals:
                            List(viewModel.goals) { goal in
                                NavigationLink(value: goal) {
                                    GoalCard(goal: goal)
                                }
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                                .contextMenu {
                                    Button(role: .destructive) {
                                        Task { await viewModel.deleteGoal(id: goal.id) }
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                            }
                            .listStyle(.plain)
                            .contentMargins(.bottom, 90, for: .scrollContent)
                            .refreshable { await viewModel.load() }
                            .errorAlert(message: $viewModel.error)

                        case .initiatives:
                            ScrollView {
                                LazyVStack(spacing: 0) {
                                    ForEach(viewModel.initiatives) { initiative in
                                        NavigationLink(value: initiative) {
                                            InitiativeCard(initiative: initiative)
                                        }
                                        .buttonStyle(.plain)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                        .contextMenu {
                                            Button(role: .destructive) {
                                                Task { await viewModel.deleteInitiative(id: initiative.id) }
                                            } label: {
                                                Label("Delete", systemImage: "trash")
                                            }
                                        }
                                    }
                                }
                            }
                            .refreshable { await viewModel.load() }
                            .errorAlert(message: $viewModel.error)

                        case .tasks:
                            List(viewModel.tasks) { task in
                                NavigationLink(value: task) {
                                    TaskRow(task: task)
                                }
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                                .contextMenu {
                                    Button(role: .destructive) {
                                        Task { await viewModel.deleteTask(id: task.id) }
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                            }
                            .listStyle(.plain)
                            .contentMargins(.bottom, 90, for: .scrollContent)
                            .refreshable { await viewModel.load() }
                            .errorAlert(message: $viewModel.error)
                        }
                    }
                }
            }
            .navigationTitle("Plans")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        switch selectedSection {
                        case .goals: showingAddGoal = true
                        case .initiatives: showingAddInitiative = true
                        case .tasks: showingAddTask = true
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .navigationDestination(for: Goal.self) { goal in
                GoalDetailView(goalId: goal.id)
            }
            .navigationDestination(for: Initiative.self) { initiative in
                InitiativeDetailView(initiativeId: initiative.id)
            }
            .navigationDestination(for: MCTask.self) { task in
                TaskDetailView(taskId: task.id)
            }
            .sheet(isPresented: $showingAddGoal) {
                AddGoalSheet { emoji, name, focus, timeline, story in
                    Task {
                        _ = try? await APIClient.shared.createGoal(
                            CreateGoalBody(emoji: emoji, name: name, focus: focus,
                                          timeline: timeline, story: story)
                        )
                        await viewModel.load()
                    }
                }
            }
            .sheet(isPresented: $showingAddInitiative) {
                AddInitiativeSheet { emoji, name, mission in
                    Task {
                        _ = try? await APIClient.shared.createInitiative(
                            CreateInitiativeBody(emoji: emoji, name: name, goalId: nil,
                                                 mission: mission, status: nil)
                        )
                        await viewModel.load()
                    }
                }
            }
            .sheet(isPresented: $showingAddTask) {
                AddTaskSheet { name, objective, emoji in
                    Task {
                        _ = try? await APIClient.shared.createTask(
                            CreateTaskBody(name: name, objective: objective, initiativeId: nil,
                                          emoji: emoji, requirements: nil, tests: nil)
                        )
                        await viewModel.load()
                    }
                }
            }
            .task { await viewModel.load() }
            .chatContext(.plans(section: selectedSection.rawValue))
        }
    }
}

// MARK: - Add Goal Sheet

struct AddGoalSheet: View {
    let onSave: (String, String, String?, String?, String?) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var emoji = ""
    @State private var name = ""
    @State private var focus = "steady"
    @State private var timeline = ""
    @State private var story = ""

    private let focusOptions = ["sprint", "steady", "simmer", "dormant"]

    var body: some View {
        NavigationStack {
            Form {
                Section("Goal Info") {
                    HStack {
                        Text("Emoji")
                        Spacer()
                        TextField("🎯", text: $emoji)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 50)
                    }
                    TextField("Goal name", text: $name)
                }

                Section("Focus") {
                    Picker("Focus Level", selection: $focus) {
                        ForEach(focusOptions, id: \.self) { f in
                            Text(f.prefix(1).uppercased() + f.dropFirst()).tag(f)
                        }
                    }
                    .pickerStyle(.segmented)
                    TextField("Timeline (optional)", text: $timeline)
                }

                Section("Story") {
                    TextEditor(text: $story)
                        .frame(minHeight: 80)
                }
            }
            .navigationTitle("New Goal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        onSave(
                            emoji.isEmpty ? "🎯" : emoji,
                            name,
                            focus,
                            timeline.isEmpty ? nil : timeline,
                            story.isEmpty ? nil : story
                        )
                        dismiss()
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
    }
}
