import Foundation
import Observation

@Observable
final class DashboardViewModel {
    var goals: [Goal] = []
    var isLoading = false
    var error: String?

    func load() async {
        isLoading = true
        error = nil
        do {
            goals = try await APIClient.shared.goals()
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
}
