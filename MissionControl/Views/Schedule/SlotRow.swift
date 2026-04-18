import SwiftUI

struct SlotRow: View {
    let slot: ScheduleSlot

    var body: some View {
        HStack(spacing: 12) {
            // Time column
            Text(slot.time)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 42, alignment: .leading)

            // Status indicator
            Image(systemName: slot.statusIcon)
                .foregroundStyle(slot.statusColor)
                .frame(width: 18)

            // Content
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(slot.typeLabel)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(slot.isDimmed ? .secondary : .primary)

                    if slot.type != "task" && slot.type != "flex" {
                        Image(systemName: slot.typeIcon)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }

                if let task = slot.task, let objective = task.objective {
                    Text(objective)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            // Goal emoji if available
            if let task = slot.task {
                Text(task.resolvedEmoji)
                    .font(.caption)
            }
        }
        .padding(.vertical, 4)
        .opacity(slot.status == "skipped" ? 0.4 : 1)
    }
}
