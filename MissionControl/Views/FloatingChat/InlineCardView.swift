import SwiftUI

/// Renders a single `card` part inline in the chat transcript. Reads the
/// hydrated row out of `EntityCache`; if the ref isn't cached yet, shows a
/// quiet placeholder and kicks a hydrate. The cache dedupes concurrent
/// requests, so the `.task` retry is safe even when the enclosing
/// `ChatConversationView` already prefetched the turn's refs in bulk.
///
/// Tap-to-navigate is intentionally absent here — the deep-link router
/// (build-order step 7) is what wires `/tasks/<id>` etc. into the nav stack.
/// Until then cards render read-only.
struct InlineCardView: View {
    let kind: CardKind
    let entityId: String
    let cache: EntityCache

    var body: some View {
        content
            .task(id: refKey) {
                await cache.hydrate([(kind, entityId)])
            }
    }

    private var refKey: String { "\(kind.rawValue):\(entityId)" }

    @ViewBuilder
    private var content: some View {
        switch kind {
        case .task:
            if let task = cache.task(entityId) {
                TaskCard(task: task)
            } else {
                placeholder("Task")
            }
        case .goal:
            if let goal = cache.goal(entityId) {
                GoalCard(goal: goal)
            } else {
                placeholder("Goal")
            }
        case .initiative:
            if let initiative = cache.initiative(entityId) {
                InitiativeCard(initiative: initiative)
            } else {
                placeholder("Initiative")
            }
        case .slot:
            if let slot = cache.slot(entityId) {
                SlotCard(slot: slot)
            } else {
                placeholder("Slot")
            }
        case .agentAssignment:
            if let assignment = cache.agentAssignment(entityId) {
                AgentAssignmentInlineRow(assignment: assignment)
            } else {
                placeholder("Agent Assignment")
            }
        case .scheduleDay:
            if let slots = cache.scheduleDay(entityId) {
                ScheduleDayInlineRow(date: entityId, slots: slots)
            } else {
                placeholder("Schedule \(entityId)")
            }
        case .unknown:
            placeholder("Card")
        }
    }

    private func placeholder(_ title: String) -> some View {
        HStack(spacing: 10) {
            ProgressView().controlSize(.small)
            Text(title)
                .font(.body)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .cardStyle(.compact)
    }
}

/// Lightweight inline row for `card.agent_assignment`. The richer dedicated
/// `AgentAssignmentCard` view (per IOS_MESSAGE_PARTS_PLAN §5.2) lands in a
/// later step; this stub renders enough to confirm hydration without
/// blocking the InlineCardView dispatch surface.
private struct AgentAssignmentInlineRow: View {
    let assignment: AgentAssignment

    var body: some View {
        HStack(spacing: 12) {
            AgentAssignmentStatusIcon(assignment: assignment, font: .title3)
            VStack(alignment: .leading, spacing: 2) {
                Text(assignment.title)
                    .font(.body)
                    .fontWeight(.medium)
                    .lineLimit(1)
                if let desc = assignment.description, !desc.isEmpty {
                    Text(desc)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            Spacer()
            Text(assignment.statusLabel)
                .font(.caption)
                .foregroundStyle(assignment.statusColor)
        }
        .cardStyle(.compact)
    }
}

/// Lightweight inline row for `card.schedule_day`. Replaced by a dedicated
/// `ScheduleDayCard` (with per-slot rows) in a later build-order step.
private struct ScheduleDayInlineRow: View {
    let date: String
    let slots: [ScheduleSlot]

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "calendar")
                .foregroundStyle(.blue)
                .font(.title3)
            VStack(alignment: .leading, spacing: 2) {
                Text(date)
                    .font(.body)
                    .fontWeight(.medium)
                Text("\(slots.count) slot\(slots.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .cardStyle(.compact)
    }
}
