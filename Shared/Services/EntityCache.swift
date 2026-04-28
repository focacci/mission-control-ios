import Foundation
import Observation

/// In-memory cache of hydrated entity rows referenced by `MessagePart.card`.
/// A `card` part on the wire carries only `{ cardType, entityId }`; the
/// renderer needs the actual row (name, status, emoji, …) to draw an inline
/// card. `EntityCache` collects refs from all rendered turns and resolves
/// them in one round-trip via `POST /api/cards/hydrate`.
///
/// Keyed by `(CardKind, id)` — the same id space the API uses (entity id for
/// task/goal/initiative/agent_assignment/slot, ISO date for schedule_day).
/// Inflight requests are deduped so concurrent `InlineCardView`s asking for
/// the same ref don't double-fetch.
@MainActor
@Observable
final class EntityCache {
    private(set) var tasks: [String: MCTask] = [:]
    private(set) var goals: [String: Goal] = [:]
    private(set) var initiatives: [String: Initiative] = [:]
    private(set) var agentAssignments: [String: AgentAssignment] = [:]
    private(set) var slots: [String: ScheduleSlot] = [:]
    private(set) var scheduleDays: [String: [ScheduleSlot]] = [:]

    private var inflight: Set<String> = []

    func task(_ id: String) -> MCTask? { tasks[id] }
    func goal(_ id: String) -> Goal? { goals[id] }
    func initiative(_ id: String) -> Initiative? { initiatives[id] }
    func agentAssignment(_ id: String) -> AgentAssignment? { agentAssignments[id] }
    func slot(_ id: String) -> ScheduleSlot? { slots[id] }
    func scheduleDay(_ date: String) -> [ScheduleSlot]? { scheduleDays[date] }

    func has(_ kind: CardKind, _ id: String) -> Bool {
        switch kind {
        case .task:            return tasks[id] != nil
        case .goal:            return goals[id] != nil
        case .initiative:      return initiatives[id] != nil
        case .agentAssignment: return agentAssignments[id] != nil
        case .slot:            return slots[id] != nil
        case .scheduleDay:     return scheduleDays[id] != nil
        case .unknown:         return true
        }
    }

    /// Resolve any refs not already cached or already in-flight. Best-effort:
    /// network failures leave the cache untouched and the placeholder stays
    /// visible. Callers wait on the @Observable change to re-render.
    func hydrate(_ refs: [(CardKind, String)]) async {
        let needed = refs.filter { kind, id in
            kind != .unknown && !has(kind, id) && !inflight.contains(Self.key(kind, id))
        }
        guard !needed.isEmpty else { return }
        for (kind, id) in needed { inflight.insert(Self.key(kind, id)) }
        defer {
            for (kind, id) in needed { inflight.remove(Self.key(kind, id)) }
        }

        do {
            let response = try await APIClient.shared.hydrateCards(refs: needed)
            apply(response)
        } catch {
            // Swallow: placeholder remains; a future render will retry.
        }
    }

    private func apply(_ r: HydrateCardsResponse) {
        for t in r.task ?? [] { tasks[t.id] = t }
        for g in r.goal ?? [] { goals[g.id] = g }
        for i in r.initiative ?? [] { initiatives[i.id] = i }
        for a in r.agentAssignment ?? [] { agentAssignments[a.id] = a }
        for s in r.slot ?? [] { slots[s.id] = s }
        for d in r.scheduleDay ?? [] { scheduleDays[d.date] = d.slots }
    }

    private static func key(_ kind: CardKind, _ id: String) -> String {
        "\(kind.rawValue):\(id)"
    }
}
