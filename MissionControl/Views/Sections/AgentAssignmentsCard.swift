import SwiftUI

struct AgentAssignmentsCard: View {
    let assignments: [AgentAssignment]
    let isSaving: Bool
    let onDelete: (String) -> Void
    let onAdd: () -> Void

    var body: some View {
        SectionCard(title: "Agent Assignments", icon: "person.badge.clock") {
            VStack(alignment: .leading, spacing: 8) {
                if assignments.isEmpty {
                    Text("Add an agent assignment to delegate supplemental work on this task.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(assignments) { aa in
                        NavigationLink(value: aa) {
                            AgentAssignmentRow(assignment: aa)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            OpenChatAboutMenuItem(
                                kind: .agentAssignment(id: aa.id, title: aa.title)
                            )
                            Button(role: .destructive) {
                                onDelete(aa.id)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                onDelete(aa.id)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }

                Button(action: onAdd) {
                    Label("Add Agent Assignment", systemImage: "plus")
                        .font(.subheadline)
                        .foregroundStyle(.blue)
                }
                .padding(.top, assignments.isEmpty ? 0 : 4)
                .disabled(isSaving)
            }
        }
    }
}

private struct AgentAssignmentRow: View {
    let assignment: AgentAssignment

    var slotCount: Int { assignment.slots?.count ?? 0 }

    var body: some View {
        HStack(spacing: 10) {
            AgentAssignmentStatusIcon(assignment: assignment, font: .title3)

            VStack(alignment: .leading, spacing: 2) {
                Text(assignment.title)
                    .font(.body)
                    .foregroundStyle(assignment.isDone ? .secondary : .primary)
                    .strikethrough(assignment.isDone)
                    .multilineTextAlignment(.leading)

                if slotCount > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "calendar.badge.clock")
                            .font(.caption2)
                        Text("\(slotCount) slot\(slotCount == 1 ? "" : "s") scheduled")
                            .font(.caption)
                    }
                    .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .contentShape(Rectangle())
    }
}
