import SwiftUI

struct WatchTaskList: View {
    @State private var tasks: [MCTask] = []
    @State private var isLoading = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Group {
                if isLoading && tasks.isEmpty {
                    ProgressView()
                } else if let error {
                    VStack(spacing: 6) {
                        Image(systemName: "wifi.slash")
                        Text(error)
                            .font(.caption2)
                            .multilineTextAlignment(.center)
                        Button("Retry") { Task { await load() } }
                    }
                } else if tasks.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "checkmark.circle")
                            .font(.title2)
                            .foregroundStyle(.green)
                        Text("No active tasks")
                            .font(.body)
                    }
                } else {
                    List {
                        ForEach(tasks) { task in
                            NavigationLink(destination: WatchTaskDetail(taskId: task.id)) {
                                HStack(spacing: 8) {
                                    Text(task.resolvedEmoji)
                                        .font(.title3)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(task.resolvedName)
                                            .font(.body)
                                            .lineLimit(2)
                                        let progress = task.requirementProgress
                                        if !progress.isEmpty {
                                            Text(progress)
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Active")
        }
        .task { await load() }
    }

    private func load() async {
        isLoading = true
        error = nil
        do {
            tasks = try await APIClient.shared.tasks(statuses: ["in-progress"])
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }
}
