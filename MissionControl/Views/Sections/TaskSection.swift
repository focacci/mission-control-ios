import SwiftUI

struct TaskSection: View {
    let title: String
    let tasks: [MCTask]
    let viewModel: InitiativeDetailViewModel
    let onBlock: ((String) -> Void)?

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
                    .swipeActions(edge: .leading, allowsFullSwipe: false) {
                        if task.canStart {
                            Button {
                                Task { await viewModel.startTask(id: task.id) }
                            } label: {
                                Label("Start", systemImage: "play.fill")
                            }
                            .tint(.blue)
                        }
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            Task { await viewModel.cancelTask(id: task.id) }
                        } label: {
                            Label("Cancel", systemImage: "xmark")
                        }

                        if let onBlock, task.canBlock {
                            Button {
                                onBlock(task.id)
                            } label: {
                                Label("Block", systemImage: "exclamationmark.circle")
                            }
                            .tint(.orange)
                        }
                    }
                }
            }
        }
    }
}
