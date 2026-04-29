import SwiftUI
import Observation

@Observable
final class AgentAssignmentsListViewModel {
    var assignments: [AgentAssignment] = []
    var isLoading = false
    var error: String?

    func load() async {
        isLoading = true
        do {
            assignments = try await APIClient.shared.allAgentAssignments()
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }
}

/// Aggregate list of every Agent Assignment across all parents (goals,
/// initiatives, tasks). Pushed from the More tab's "Agent" section.
struct AgentAssignmentsListView: View {
    @State private var viewModel = AgentAssignmentsListViewModel()

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.assignments.isEmpty {
                ProgressView("Loading…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.assignments.isEmpty {
                ContentUnavailableView(
                    "No Agent Assignments",
                    systemImage: "person.badge.clock",
                    description: Text("Create agent assignments under a goal, initiative, or task.")
                )
            } else {
                List {
                    ForEach(viewModel.assignments) { aa in
                        NavigationLink(value: aa) {
                            AgentAssignmentListRow(assignment: aa)
                        }
                        .contextMenu {
                            OpenChatAboutMenuItem(
                                kind: .agentAssignment(id: aa.id, title: aa.title)
                            )
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("Agent Assignments")
        .navigationBarTitleDisplayMode(.inline)
        .chatContext(.agentAssignments)
        .chatContextToolbar()
        .task { await viewModel.load() }
        .refreshable { await viewModel.load() }
        .errorAlert(message: $viewModel.error)
        .navigationDestination(for: AgentAssignment.self) { aa in
            AgentAssignmentDetailView(assignment: aa)
        }
        .navigationDestination(for: AgentOutput.self) { output in
            AgentOutputDetailView(output: output)
        }
    }
}

private struct AgentAssignmentListRow: View {
    let assignment: AgentAssignment

    private var slotCount: Int { assignment.slots?.count ?? 0 }

    private var parentLabel: String {
        if assignment.goalId != nil { return "Goal" }
        if assignment.initiativeId != nil { return "Initiative" }
        if assignment.taskId != nil { return "Task" }
        return "Unattached"
    }

    var body: some View {
        HStack(spacing: 10) {
            AgentAssignmentStatusIcon(assignment: assignment, font: .title3)

            VStack(alignment: .leading, spacing: 4) {
                Text(assignment.title)
                    .font(.body)
                    .foregroundStyle(assignment.isDone ? .secondary : .primary)
                    .strikethrough(assignment.isDone)
                    .multilineTextAlignment(.leading)

                HStack(spacing: 8) {
                    Text(parentLabel)
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.15), in: Capsule())
                        .foregroundStyle(.secondary)

                    Text(assignment.statusLabel)
                        .font(.caption)
                        .foregroundStyle(assignment.statusColor)

                    if slotCount > 0 {
                        HStack(spacing: 3) {
                            Image(systemName: "calendar.badge.clock")
                                .font(.caption2)
                            Text("\(slotCount)")
                                .font(.caption)
                        }
                        .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()
        }
        .contentShape(Rectangle())
    }
}
