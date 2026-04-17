import SwiftUI

struct TaskRow: View {
    let task: MCTask

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: task.statusIcon)
                .foregroundStyle(task.statusColor)
                .font(.title3)
                .frame(width: 24)

            Text(task.resolvedEmoji)
                .font(.title3)

            VStack(alignment: .leading, spacing: 2) {
                Text(task.name)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                if let obj = task.objective, !obj.isEmpty {
                    Text(obj)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            let progress = task.requirementProgress
            if !progress.isEmpty {
                Text(progress)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(.secondary.opacity(0.12), in: Capsule())
            }

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}
