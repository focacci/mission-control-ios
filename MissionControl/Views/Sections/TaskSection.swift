import SwiftUI

struct TaskSection: View {
    let title: String
    let tasks: [MCTask]
    let viewModel: InitiativeDetailViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)

            VStack(spacing: 8) {
                ForEach(tasks) { task in
                    NavigationLink(value: task) {
                        TaskCard(task: task)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        OpenChatAboutMenuItem(
                            kind: .task(id: task.id, name: task.name)
                        )
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        if task.isDone {
                            Button {
                                Task { await viewModel.reopenTask(id: task.id) }
                            } label: {
                                Label("Reopen", systemImage: "arrow.uturn.backward")
                            }
                            .tint(.gray)
                        }

                        Button(role: .destructive) {
                            Task { await viewModel.deleteTask(id: task.id) }
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
        }
    }
}
