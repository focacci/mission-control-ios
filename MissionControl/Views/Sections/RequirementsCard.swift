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
