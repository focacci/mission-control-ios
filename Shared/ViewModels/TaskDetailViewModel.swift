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

    func startTask() async {
        guard let id = task?.id else { return }
        isSaving = true
        do {
            task = try await APIClient.shared.startTask(id: id)
        } catch {
            self.error = error.localizedDescription
        }
        isSaving = false
    }

    func completeTask(summary: String) async {
        guard let id = task?.id else { return }
        isSaving = true
        do {
            task = try await APIClient.shared.completeTask(id: id, body: CompleteTaskBody(summary: summary, outputs: nil))
        } catch {
            self.error = error.localizedDescription
        }
        isSaving = false
    }

    func blockTask(reason: String) async {
        guard let id = task?.id else { return }
        isSaving = true
        do {
            task = try await APIClient.shared.blockTask(id: id, reason: reason)
        } catch {
            self.error = error.localizedDescription
        }
        isSaving = false
    }

    func cancelTask() async {
        guard let id = task?.id else { return }
        isSaving = true
        do {
            task = try await APIClient.shared.cancelTask(id: id)
        } catch {
            self.error = error.localizedDescription
        }
        isSaving = false
    }

    func toggleRequirement(reqId: String) async {
        guard let taskId = task?.id,
              let req = task?.requirements?.first(where: { $0.id == reqId }) else { return }
        do {
            let updated: Requirement
            if req.completed {
                updated = try await APIClient.shared.uncheckRequirement(taskId: taskId, reqId: reqId)
            } else {
                updated = try await APIClient.shared.checkRequirement(taskId: taskId, reqId: reqId)
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
        guard let taskId = task?.id else { return }
        do {
            try await APIClient.shared.deleteRequirement(taskId: taskId, reqId: reqId)
            if let t = task {
                let reqs = (t.requirements ?? []).filter { $0.id != reqId }
                task = rebuildTask(t, requirements: reqs)
            }
        } catch {
            self.error = error.localizedDescription
        }
    }

    func addTest(description: String) async {
        guard let taskId = task?.id else { return }
        do {
            let test = try await APIClient.shared.addTest(taskId: taskId, description: description)
            if let t = task {
                var tests = t.tests ?? []
                tests.append(test)
                task = rebuildTask(t, tests: tests)
            }
        } catch {
            self.error = error.localizedDescription
        }
    }

    func deleteTest(testId: String) async {
        guard let taskId = task?.id else { return }
        do {
            try await APIClient.shared.deleteTest(taskId: taskId, testId: testId)
            if let t = task {
                let tests = (t.tests ?? []).filter { $0.id != testId }
                task = rebuildTask(t, tests: tests)
            }
        } catch {
            self.error = error.localizedDescription
        }
    }

    func addOutput(label: String, url: String?) async {
        guard let taskId = task?.id else { return }
        do {
            let output = try await APIClient.shared.addOutput(taskId: taskId, label: label, url: url)
            if let t = task {
                var outputs = t.outputs ?? []
                outputs.append(output)
                task = rebuildTask(t, outputs: outputs)
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
        tests: [TaskTest]? = nil,
        outputs: [TaskOutput]? = nil
    ) -> MCTask {
        MCTask(
            id: t.id, emoji: t.emoji, name: t.name,
            initiativeId: t.initiativeId, status: t.status, objective: t.objective,
            summary: t.summary,
            requirements: requirements ?? t.requirements,
            tests: tests ?? t.tests,
            outputs: outputs ?? t.outputs,
            initiative: t.initiative,
            slot: t.slot
        )
    }
}
