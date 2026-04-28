import SwiftUI

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
                    NavigationLink(value: req) {
                        RequirementRow(
                            requirement: req,
                            isSaving: isSaving,
                            onToggle: { onToggle(req.id) }
                        )
                    }
                    .buttonStyle(.plain)
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

private struct RequirementRow: View {
    let requirement: Requirement
    let isSaving: Bool
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Button {
                onToggle()
            } label: {
                Image(systemName: requirement.completed ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(requirement.completed ? .green : .secondary)
                    .font(.title3)
            }
            .buttonStyle(.plain)
            .disabled(isSaving)

            VStack(alignment: .leading, spacing: 2) {
                Text(requirement.description)
                    .font(.body)
                    .foregroundStyle(requirement.completed ? .secondary : .primary)
                    .strikethrough(requirement.completed)
                    .multilineTextAlignment(.leading)

                let progress = requirement.testsProgress
                if !progress.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.shield")
                            .font(.caption2)
                        Text("\(progress) tests passing")
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
