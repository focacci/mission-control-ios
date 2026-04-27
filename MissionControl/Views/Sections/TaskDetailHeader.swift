import SwiftUI

struct TaskDetailHeader: View {
    let task: MCTask

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(task.name)
                .font(.title2)
                .fontWeight(.bold)
                .multilineTextAlignment(.leading)

            if task.goal != nil || task.initiative != nil {
                VStack(alignment: .leading, spacing: 6) {
                    if let goal = task.goal {
                        ParentReferenceRow(
                            icon: "trophy",
                            emoji: goal.emoji,
                            name: goal.name,
                            destination: { GoalDetailView(goalId: goal.id) }
                        )
                    }

                    if let initiative = task.initiative {
                        ParentReferenceRow(
                            icon: "flag.pattern.checkered",
                            emoji: initiative.emoji,
                            name: initiative.name,
                            destination: { InitiativeDetailView(initiativeId: initiative.id) }
                        )
                    }
                }
            }

            if let objective = task.objective, !objective.isEmpty {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Image(systemName: "target")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .frame(width: 20)
                    Text(objective)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}

struct ParentReferenceRow<Destination: View>: View {
    let icon: String
    let emoji: String
    let name: String
    @ViewBuilder let destination: () -> Destination

    @State private var showingSheet = false

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(width: 20)

            Button {
                showingSheet = true
            } label: {
                Text("\(emoji) \(name)")
                    .font(.subheadline)
                    .lineLimit(1)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.clear, in: Capsule())
                    .overlay(Capsule().strokeBorder(.secondary.opacity(0.4), lineWidth: 1))
            }
            .buttonStyle(.plain)

            Spacer(minLength: 0)
        }
        .sheet(isPresented: $showingSheet) {
            NavigationStack {
                destination()
                    .environment(\.chatContextFrozen, true)
                    .environment(\.pullToRefreshDisabled, true)
                    .toolbar(.hidden, for: .navigationBar)
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
    }
}
