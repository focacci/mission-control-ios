import Foundation
import Observation

@Observable
final class PlansViewModel {
    var goals: [Goal] = []
    var initiatives: [Initiative] = []
    var tasks: [MCTask] = []
    var isLoading = false
    var error: String?

    func load() async {
        isLoading = true
        error = nil
        do {
            async let fetchedGoals = APIClient.shared.goals()
            async let fetchedInitiatives = APIClient.shared.initiatives()
            async let fetchedTasks = APIClient.shared.tasks()
            (goals, initiatives, tasks) = try await (fetchedGoals, fetchedInitiatives, fetchedTasks)
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    func deleteGoal(id: String) async {
        do {
            try await APIClient.shared.deleteGoal(id: id)
            goals.removeAll { $0.id == id }
        } catch {
            self.error = error.localizedDescription
        }
    }

    func deleteInitiative(id: String) async {
        do {
            try await APIClient.shared.deleteInitiative(id: id)
            initiatives.removeAll { $0.id == id }
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
}
