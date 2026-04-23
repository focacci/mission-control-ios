import SwiftUI

struct SlotCard: View {
    let slot: ScheduleSlot
    var showBreadcrumb: Bool = false

    private var isBrief: Bool { slot.type == .brief }
    private var isEmpty: Bool { slot.isOpenSlot }

    private var statusIcon: String {
        slot.task?.statusIcon ?? slot.statusIcon
    }

    private var statusColor: Color {
        slot.task?.statusColor ?? slot.statusColor
    }

    private var breadcrumb: String? {
        guard let task = slot.task,
              let goalName = task.goal?.name,
              let initiativeName = task.initiative?.name else { return nil }
        return "\(goalName) › \(initiativeName)"
    }

    var body: some View {
        HStack(spacing: 12) {
            Text(slot.time)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(isBrief ? Color.accentColor.opacity(0.85) : .secondary)
                .frame(width: 42, alignment: .leading)

            if isEmpty {
                Text("Empty")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
                Spacer()
            } else {
                Image(systemName: statusIcon)
                    .foregroundStyle(statusColor)
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: 2) {
                    Text(slot.typeLabel)
                        .font(.subheadline)
                        .fontWeight(isBrief ? .semibold : .medium)
                        .foregroundStyle(isBrief ? Color.accentColor : (slot.isDimmed ? .secondary : .primary))
                        .lineLimit(1)

                    if showBreadcrumb, let crumb = breadcrumb {
                        Text(crumb)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    } else if let task = slot.task, let objective = task.objective, !objective.isEmpty {
                        Text(objective)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer()
            }
        }
        .opacity(slot.status == .skipped ? 0.45 : 1)
        .modifier(SlotCardChrome(isEmpty: isEmpty))
        .overlay(alignment: .leading) {
            if isBrief {
                Rectangle()
                    .fill(Color.accentColor.opacity(0.8))
                    .frame(width: 3)
                    .padding(.vertical, 6)
                    .clipShape(RoundedRectangle(cornerRadius: 2))
            }
        }
    }
}

/// Empty slots render with a faint dashed outline and no filled background so
/// they read as "available to assign" instead of looking like committed work.
private struct SlotCardChrome: ViewModifier {
    let isEmpty: Bool

    func body(content: Content) -> some View {
        if isEmpty {
            content
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.regularMaterial.opacity(0.35), in: RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(
                            Color.secondary.opacity(0.35),
                            style: StrokeStyle(lineWidth: 1, dash: [4, 3])
                        )
                )
        } else {
            content.cardStyle(.compact)
        }
    }
}
