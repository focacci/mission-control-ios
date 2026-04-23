import Foundation
import Observation

@Observable
final class InitiativeDetailViewModel {
    var initiative: Initiative?
    var tasks: [MCTask] = []
    var isLoading = false
    var error: String?

    var inProgressTasks: [MCTask] { tasks.filter { $0.status == "in-progress" } }
    var activeTasks: [MCTask] { tasks.filter { $0.status == "pending" || $0.status == "assigned" } }
    var doneTasks: [MCTask] { tasks.filter { $0.status == "done" || $0.status == "cancelled" } }
    var blockedTasks: [MCTask] { tasks.filter { $0.status == "blocked" } }

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

    func startTask(id: String) async {
        do {
            let updated = try await APIClient.shared.startTask(id: id)
            replaceTask(updated)
        } catch {
            self.error = error.localizedDescription
        }
    }

    func blockTask(id: String, reason: String) async {
        do {
            let updated = try await APIClient.shared.blockTask(id: id, reason: reason)
            replaceTask(updated)
        } catch {
            self.error = error.localizedDescription
        }
    }

    func cancelTask(id: String) async {
        do {
            let updated = try await APIClient.shared.cancelTask(id: id)
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

    private func replaceTask(_ updated: MCTask) {
        if let idx = tasks.firstIndex(where: { $0.id == updated.id }) {
            tasks[idx] = updated
        }
    }
}
