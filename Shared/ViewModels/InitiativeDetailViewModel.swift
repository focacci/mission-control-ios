import Foundation
import Observation

@Observable
final class InitiativeDetailViewModel {
    var initiative: Initiative?
    var tasks: [MCTask] = []
    var isLoading = false
    var error: String?
    var isSaving = false

    var pendingTasks: [MCTask] { tasks.filter { $0.status == "pending" } }
    var doneTasks: [MCTask] { tasks.filter { $0.status == "done" } }

    func load(id: String) async {
        isLoading = true
        error = nil
        do {
            initiative = try await APIClient.shared.initiative(id: id)
            tasks = initiative?.tasks ?? []
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    func reopenTask(id: String) async {
        do {
            let updated = try await APIClient.shared.reopenTask(id: id)
            replaceTask(updated)
        } catch {
            self.error = error.localizedDescription
        }
    }

    func deleteTask(id: String) async {
        do {
            try await APIClient.shared.deleteTask(id: id)
            tasks.removeAll { $0.id == id }
        } catch {
            self.error = error.localizedDescription
        }
    }

    func deleteInitiative(id: String) async -> Bool {
        do {
            try await APIClient.shared.deleteInitiative(id: id)
            return true
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }

    func update(id: String, body: UpdateInitiativeBody) async {
        do {
            initiative = try await APIClient.shared.updateInitiative(id: id, body: body)
        } catch {
            self.error = error.localizedDescription
        }
    }

    func createTask(name: String, objective: String, emoji: String?) async {
        guard let initiativeId = initiative?.id else { return }
        do {
            let task = try await APIClient.shared.createTask(
                CreateTaskBody(name: name, objective: objective, initiativeId: initiativeId,
                               emoji: emoji.flatMap { $0.isEmpty ? nil : $0 },
                               requirements: nil)
            )
            tasks.append(task)
        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: - Agent Assignments

    func addAgentAssignment(title: String, instructions: String) async {
        guard let initiativeId = initiative?.id else { return }
        isSaving = true
        do {
            let aa = try await APIClient.shared.createAgentAssignment(
                initiativeId: initiativeId,
                body: CreateAgentAssignmentBody(title: title, instructions: instructions, agentId: nil)
            )
            if let i = initiative {
                var aas = i.agentAssignments ?? []
                aas.append(aa)
                initiative = rebuildInitiative(i, agentAssignments: aas)
            }
        } catch {
            self.error = error.localizedDescription
        }
        isSaving = false
    }

    func deleteAgentAssignment(id: String) async {
        do {
            try await APIClient.shared.deleteAgentAssignment(id: id)
            if let i = initiative {
                let remaining = (i.agentAssignments ?? []).filter { $0.id != id }
                initiative = rebuildInitiative(i, agentAssignments: remaining)
            }
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func replaceTask(_ updated: MCTask) {
        if let idx = tasks.firstIndex(where: { $0.id == updated.id }) {
            tasks[idx] = updated
        }
    }

    private func rebuildInitiative(
        _ i: Initiative,
        agentAssignments: [AgentAssignment]? = nil
    ) -> Initiative {
        Initiative(
            id: i.id, emoji: i.emoji, name: i.name,
            goalId: i.goalId, status: i.status, mission: i.mission,
            goal: i.goal, tasks: i.tasks,
            agentAssignments: agentAssignments ?? i.agentAssignments
        )
    }
}
