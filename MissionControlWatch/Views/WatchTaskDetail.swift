import SwiftUI

struct WatchTaskDetail: View {
    let taskId: String
    @State private var task: MCTask?
    @State private var isLoading = false
    @State private var isSaving = false
    @State private var error: String?

    var body: some View {
        ScrollView {
            if isLoading && task == nil {
                ProgressView()
                    .padding()
            } else if let task {
                VStack(alignment: .leading, spacing: 10) {
                    // Header
                    HStack {
                        Spacer()
                        Image(systemName: task.statusIcon)
                            .foregroundStyle(task.statusColor)
                    }

                    Text(task.name)
                        .font(.headline)

                    if let objective = task.objective, !objective.isEmpty {
                        Text(objective)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Divider()

                    // Requirements
                    let reqs = task.requirements ?? []
                    if !reqs.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Requirements")
                                .font(.caption.bold())
                                .foregroundStyle(.secondary)

                            ForEach(reqs) { req in
                                Button {
                                    Task { await toggleRequirement(taskId: task.id, req: req) }
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: req.completed ? "checkmark.circle.fill" : "circle")
                                            .foregroundStyle(req.completed ? .green : .secondary)
                                            .font(.body)
                                        Text(req.description)
                                            .font(.caption)
                                            .foregroundStyle(req.completed ? .secondary : .primary)
                                            .strikethrough(req.completed)
                                            .multilineTextAlignment(.leading)
                                        Spacer()
                                    }
                                }
                                .disabled(isSaving)
                            }
                        }
                    }

                    // Action
                    if task.canStart {
                        Button {
                            Task { await startTask(id: task.id) }
                        } label: {
                            Label("Start", systemImage: "play.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.blue)
                        .disabled(isSaving)
                    }
                }
                .padding(.horizontal, 6)
            } else if let error {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding()
            }
        }
        .navigationTitle("Task")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    private func load() async {
        isLoading = true
        error = nil
        do {
            task = try await APIClient.shared.task(id: taskId)
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    private func startTask(id: String) async {
        isSaving = true
        do {
            task = try await APIClient.shared.startTask(id: id)
        } catch {
            self.error = error.localizedDescription
        }
        isSaving = false
    }

    private func toggleRequirement(taskId: String, req: Requirement) async {
        isSaving = true
        do {
            let updated: Requirement
            if req.completed {
                updated = try await APIClient.shared.uncheckRequirement(taskId: taskId, reqId: req.id)
            } else {
                updated = try await APIClient.shared.checkRequirement(taskId: taskId, reqId: req.id)
            }
            if var t = task, var reqs = t.requirements,
               let idx = reqs.firstIndex(where: { $0.id == updated.id }) {
                reqs[idx] = updated
                task = MCTask(
                    id: t.id, name: t.name,
                    initiativeId: t.initiativeId, status: t.status, objective: t.objective,
                    summary: t.summary, requirements: reqs, tests: t.tests,
                    outputs: t.outputs, initiative: t.initiative, goal: t.goal, slot: t.slot
                )
            }
        } catch {
            self.error = error.localizedDescription
        }
        isSaving = false
    }
}
