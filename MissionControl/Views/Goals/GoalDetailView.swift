import SwiftUI

struct GoalDetailView: View {
    let goalId: String
    @State private var viewModel = GoalDetailViewModel()
    @State private var showingEdit = false
    @State private var showingAddInitiative = false

    var body: some View {
        Group {
            if viewModel.goal == nil && viewModel.error == nil {
                ProgressView("Loading…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let goal = viewModel.goal {
                ScrollView {
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
                    }
                    .padding()
                }
                .refreshable { await viewModel.load(id: goalId) }
                .navigationTitle("Goal")
                .navigationBarTitleDisplayMode(.large)
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button("Edit") { showingEdit = true }
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
    }
}

// MARK: - Goal Detail Header

struct GoalDetailHeader: View {
    let goal: Goal
    @State private var storyExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text(goal.emoji)
                    .font(.system(size: 56))

                Text(goal.name)
                    .font(.title2)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.leading)

                Spacer()
            }

            HStack(spacing: 12) {
                Label(goal.focusLabel, systemImage: "circle.fill")
                    .font(.subheadline)
                    .foregroundStyle(goal.focusColor)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 6)
                    .background(goal.focusColor.opacity(0.15), in: Capsule())

                if let timeline = goal.timeline, !timeline.isEmpty {
                    Label(timeline, systemImage: "calendar")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.secondary.opacity(0.1), in: Capsule())
                }

                Spacer()
            }

            if let story = goal.story, !story.isEmpty {
                Text(story)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Initiative Card

struct InitiativeCard: View {
    let initiative: Initiative

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Left column: emoji pinned top, status badge pinned bottom
            VStack(spacing: 0) {
                Text(initiative.emoji)
                    .font(.system(size: 28))

                Spacer()

                Label(initiative.statusLabel, systemImage: initiative.statusIcon)
                    .font(.caption)
                    .foregroundStyle(initiative.statusColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(initiative.statusColor.opacity(0.15), in: Capsule())
            }
            .fixedSize(horizontal: true, vertical: false)

            // Right column: name top, mission below
            VStack(alignment: .leading, spacing: 4) {
                Text(initiative.name)
                    .font(.headline)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                    .foregroundStyle(.primary)

                if let mission = initiative.mission, !mission.isEmpty {
                    Text(mission)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.12), radius: 6, x: 0, y: 3)
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
