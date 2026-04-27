import Foundation
import Observation

@Observable
final class TaskDetailViewModel {
    var task: MCTask?
    var isLoading = false
    var isSaving = false
    var error: String?

    func load(id: String) async {
        isLoading = true
        error = nil
        do {
            task = try await APIClient.shared.task(id: id)
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    func completeTask(summary: String) async {
        guard let id = task?.id else { return }
        isSaving = true
        do {
            task = try await APIClient.shared.completeTask(id: id, body: CompleteTaskBody(summary: summary))
        } catch {
            self.error = error.localizedDescription
        }
        isSaving = false
    }

    func reopenTask() async {
        guard let id = task?.id else { return }
        isSaving = true
        do {
            task = try await APIClient.shared.reopenTask(id: id)
        } catch {
            self.error = error.localizedDescription
        }
        isSaving = false
    }

    func update(id: String, body: UpdateTaskBody) async {
        isSaving = true
        do {
            task = try await APIClient.shared.updateTask(id: id, body: body)
        } catch {
            self.error = error.localizedDescription
        }
        isSaving = false
    }

    func deleteTask(id: String) async -> Bool {
        do {
            try await APIClient.shared.deleteTask(id: id)
            return true
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }

    // MARK: - Requirements

    func toggleRequirement(reqId: String) async {
        guard let req = task?.requirements?.first(where: { $0.id == reqId }) else { return }
        do {
            let updated: Requirement
            if req.completed {
                updated = try await APIClient.shared.uncheckRequirement(reqId: reqId)
            } else {
                updated = try await APIClient.shared.checkRequirement(reqId: reqId)
            }
            replaceRequirement(updated)
        } catch {
            self.error = error.localizedDescription
        }
    }

    func addRequirement(description: String) async {
        guard let taskId = task?.id else { return }
        do {
            let req = try await APIClient.shared.addRequirement(taskId: taskId, description: description)
            if let t = task {
                var reqs = t.requirements ?? []
                reqs.append(req)
                task = rebuildTask(t, requirements: reqs)
            }
        } catch {
            self.error = error.localizedDescription
        }
    }

    func deleteRequirement(reqId: String) async {
        do {
            try await APIClient.shared.deleteRequirement(reqId: reqId)
            if let t = task {
                let reqs = (t.requirements ?? []).filter { $0.id != reqId }
                task = rebuildTask(t, requirements: reqs)
            }
        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: - Agent Assignments

    func addAgentAssignment(title: String, instructions: String) async {
        guard let taskId = task?.id else { return }
        do {
            let aa = try await APIClient.shared.createAgentAssignment(
                taskId: taskId,
                body: CreateAgentAssignmentBody(title: title, instructions: instructions, agentId: nil)
            )
            if let t = task {
                var aas = t.agentAssignments ?? []
                aas.append(aa)
                task = rebuildTask(t, agentAssignments: aas)
            }
        } catch {
            self.error = error.localizedDescription
        }
    }

    func deleteAgentAssignment(id: String) async {
        do {
            try await APIClient.shared.deleteAgentAssignment(id: id)
            if let t = task {
                let aas = (t.agentAssignments ?? []).filter { $0.id != id }
                task = rebuildTask(t, agentAssignments: aas)
            }
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func replaceRequirement(_ updated: Requirement) {
        guard let t = task else { return }
        var reqs = t.requirements ?? []
        if let idx = reqs.firstIndex(where: { $0.id == updated.id }) {
            reqs[idx] = updated
        }
        task = rebuildTask(t, requirements: reqs)
    }

    private func rebuildTask(
        _ t: MCTask,
        requirements: [Requirement]? = nil,
        agentAssignments: [AgentAssignment]? = nil
    ) -> MCTask {
        MCTask(
            id: t.id, name: t.name,
            initiativeId: t.initiativeId, status: t.status, objective: t.objective,
            summary: t.summary,
            requirements: requirements ?? t.requirements,
            agentAssignments: agentAssignments ?? t.agentAssignments,
            initiative: t.initiative,
            goal: t.goal
        )
    }
}
