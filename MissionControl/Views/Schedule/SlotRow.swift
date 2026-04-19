import SwiftUI

struct SlotRow: View {
    let slot: ScheduleSlot

    private var isBrief: Bool { slot.type == "brief" }
    private var isEmpty: Bool { slot.taskId == nil && (slot.type == "flex" || slot.type == "task") }

    var body: some View {
        HStack(spacing: 12) {
            // Time column
            Text(slot.time)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(isBrief ? Color.accentColor.opacity(0.8) : .secondary)
                .frame(width: 42, alignment: .leading)

            if isEmpty {
                Text("Empty")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
                Spacer()
            } else {
                VStack(alignment: .leading, spacing: 2) {
                    Text(slot.typeLabel)
                        .font(.subheadline)
                        .fontWeight(isBrief ? .semibold : .medium)
                        .foregroundStyle(isBrief ? Color.accentColor : (slot.isDimmed ? .secondary : .primary))

                    if let task = slot.task, let objective = task.objective {
                        Text(objective)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                if let task = slot.task {
                    Text(task.resolvedEmoji)
                        .font(.caption)
                }
            }
        }
        .padding(.vertical, 4)
        .opacity(slot.status == "skipped" ? 0.4 : 1)
        .listRowBackground(isBrief ? Color.accentColor.opacity(0.08) : Color.clear)
    }
}
