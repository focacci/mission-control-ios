import Foundation
import Observation

@Observable
final class GoalDetailViewModel {
    var goal: Goal?
    var isLoading = false
    var error: String?
    var isSaving = false

    func load(id: String) async {
        isLoading = true
        error = nil
        do {
            goal = try await APIClient.shared.goal(id: id)
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    func update(id: String, body: UpdateGoalBody) async {
        isSaving = true
        do {
            let updated = try await APIClient.shared.updateGoal(id: id, body: body)
            let currentInitiatives = goal?.initiatives
            let currentAAs = goal?.agentAssignments
            goal = Goal(
                id: updated.id, emoji: updated.emoji, name: updated.name,
                focus: updated.focus,
                focusIcon: updated.focusIcon, timeline: updated.timeline,
                story: updated.story, initiatives: currentInitiatives,
                agentAssignments: currentAAs
            )
        } catch {
            self.error = error.localizedDescription
        }
        isSaving = false
    }

    func deleteGoal(id: String) async -> Bool {
        do {
            try await APIClient.shared.deleteGoal(id: id)
            return true
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }

    func deleteInitiative(id: String) async {
        do {
            try await APIClient.shared.deleteInitiative(id: id)
            if let g = goal {
                let remaining = (g.initiatives ?? []).filter { $0.id != id }
                goal = rebuildGoal(g, initiatives: remaining)
            }
        } catch {
            self.error = error.localizedDescription
        }
    }

    func createInitiative(emoji: String, name: String, mission: String?) async {
        guard let goalId = goal?.id else { return }
        do {
            let ini = try await APIClient.shared.createInitiative(
                CreateInitiativeBody(emoji: emoji, name: name, goalId: goalId,
                                     mission: mission.flatMap { $0.isEmpty ? nil : $0 }, status: nil)
            )
            if let g = goal {
                var existing = g.initiatives ?? []
                existing.append(ini)
                goal = rebuildGoal(g, initiatives: existing)
            }
        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: - Agent Assignments

    func addAgentAssignment(title: String, instructions: String) async {
        guard let goalId = goal?.id else { return }
        isSaving = true
        do {
            let aa = try await APIClient.shared.createAgentAssignment(
                goalId: goalId,
                body: CreateAgentAssignmentBody(title: title, instructions: instructions, agentId: nil)
            )
            if let g = goal {
                var aas = g.agentAssignments ?? []
                aas.append(aa)
                goal = rebuildGoal(g, agentAssignments: aas)
            }
        } catch {
            self.error = error.localizedDescription
        }
        isSaving = false
    }

    func deleteAgentAssignment(id: String) async {
        do {
            try await APIClient.shared.deleteAgentAssignment(id: id)
            if let g = goal {
                let remaining = (g.agentAssignments ?? []).filter { $0.id != id }
                goal = rebuildGoal(g, agentAssignments: remaining)
            }
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func rebuildGoal(
        _ g: Goal,
        initiatives: [Initiative]? = nil,
        agentAssignments: [AgentAssignment]? = nil
    ) -> Goal {
        Goal(
            id: g.id, emoji: g.emoji, name: g.name,
            focus: g.focus, focusIcon: g.focusIcon, timeline: g.timeline,
            story: g.story,
            initiatives: initiatives ?? g.initiatives,
            agentAssignments: agentAssignments ?? g.agentAssignments
        )
    }
}
