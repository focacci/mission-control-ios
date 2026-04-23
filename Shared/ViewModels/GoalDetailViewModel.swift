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
            goal = Goal(
                id: updated.id, emoji: updated.emoji, name: updated.name,
                focus: updated.focus,
                focusIcon: updated.focusIcon, timeline: updated.timeline,
                story: updated.story, initiatives: currentInitiatives
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
                goal = Goal(
                    id: g.id, emoji: g.emoji, name: g.name,
                    focus: g.focus, focusIcon: g.focusIcon, timeline: g.timeline,
                    story: g.story, initiatives: remaining
                )
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
                goal = Goal(
                    id: g.id, emoji: g.emoji, name: g.name,
                    focus: g.focus, focusIcon: g.focusIcon, timeline: g.timeline,
                    story: g.story, initiatives: existing
                )
            }
        } catch {
            self.error = error.localizedDescription
        }
    }
}
