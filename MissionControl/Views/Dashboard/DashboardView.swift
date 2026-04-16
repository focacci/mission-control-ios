import SwiftUI

struct DashboardView: View {
    @State private var viewModel = DashboardViewModel()
    @State private var selectedGoal: Goal?
    @State private var showingAddGoal = false

    private let columns = [
        GridItem(.adaptive(minimum: 160, maximum: 200), spacing: 16)
    ]

    var body: some View {
        NavigationSplitView {
            Group {
                if viewModel.isLoading && viewModel.goals.isEmpty {
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
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 16) {
                            ForEach(viewModel.goals) { goal in
                                GoalCard(goal: goal)
                                    .onTapGesture { selectedGoal = goal }
                                    .contextMenu {
                                        Button(role: .destructive) {
                                            Task { await viewModel.deleteGoal(id: goal.id) }
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
                            }
                        }
                        .padding()
                    }
                    .refreshable { await viewModel.load() }
                }
            }
            .navigationTitle("Mission Control")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingAddGoal = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
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
            .task { await viewModel.load() }
        } detail: {
            if let goal = selectedGoal {
                GoalDetailView(goalId: goal.id)
            } else {
                ContentUnavailableView(
                    "Select a Goal",
                    systemImage: "target",
                    description: Text("Choose a goal from the sidebar to view details.")
                )
            }
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
