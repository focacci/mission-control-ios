import Foundation
import Observation

@Observable
final class AgentsViewModel {
    var agents: [Agent] = []
    var isLoading = false
    var isCreating = false
    var error: String?

    func load() async {
        isLoading = true
        error = nil
        do {
            agents = try await APIClient.shared.agents()
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    @discardableResult
    func createAgent(name: String, model: String, systemPrompt: String?) async -> Agent? {
        isCreating = true
        error = nil
        defer { isCreating = false }
        do {
            let created = try await APIClient.shared.createAgent(
                CreateAgentBody(name: name, model: model, systemPrompt: systemPrompt)
            )
            await load()
            return created
        } catch {
            self.error = error.localizedDescription
            return nil
        }
    }

    func deleteAgent(id: String) async {
        do {
            try await APIClient.shared.deleteAgent(id: id)
            agents.removeAll { $0.id == id }
        } catch {
            self.error = error.localizedDescription
        }
    }

    @discardableResult
    func updateSystemPrompt(id: String, systemPrompt: String?) async -> Agent? {
        error = nil
        do {
            let updated = try await APIClient.shared.updateAgent(
                id: id,
                body: UpdateAgentBody(systemPrompt: systemPrompt)
            )
            if let idx = agents.firstIndex(where: { $0.id == id }) {
                agents[idx] = updated
            }
            return updated
        } catch {
            self.error = error.localizedDescription
            return nil
        }
    }

    func repair() async {
        isLoading = true
        error = nil
        do {
            agents = try await APIClient.shared.repairAgents()
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }
}
