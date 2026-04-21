import Foundation
import Observation

/// Lightweight summary of a single agent's conversation activity. Built from
/// a page of `chat_sessions` and attached per-agent so `AgentCard` can
/// surface "last chat 3h ago · 14 chats" without extra requests per row.
struct AgentActivity: Hashable {
    let chatCount: Int
    let lastMessageAt: String?
}

@Observable
final class AgentsViewModel {
    var agents: [Agent] = []
    var activity: [String: AgentActivity] = [:]
    var isLoading = false
    var isCreating = false
    var error: String?

    func load() async {
        isLoading = true
        error = nil
        do {
            agents = try await APIClient.shared.agents()
            await loadActivity()
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    /// Fetches a single page of sessions across all agents and groups by
    /// `agentId`. The server sorts by `lastMessageAt` descending, so the
    /// first session we see for each agent is the most recent one.
    private func loadActivity() async {
        do {
            let sessions = try await APIClient.shared.chatSessions(limit: 200)
            var map: [String: AgentActivity] = [:]
            for session in sessions {
                if let existing = map[session.agentId] {
                    map[session.agentId] = AgentActivity(
                        chatCount: existing.chatCount + 1,
                        lastMessageAt: existing.lastMessageAt
                    )
                } else {
                    map[session.agentId] = AgentActivity(
                        chatCount: 1,
                        lastMessageAt: session.lastMessageAt
                    )
                }
            }
            activity = map
        } catch {
            // Non-fatal — agents still render without activity metadata.
        }
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
