import SwiftUI

struct GoalCard: View {
    let goal: Goal

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 0) {
                Text(goal.emoji)
                    .font(.system(size: 28))

                Spacer()

                Text(goal.focusLabel)
                    .font(.caption)
                    .foregroundStyle(goal.focusColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(goal.focusColor.opacity(0.15), in: Capsule())
            }
            .fixedSize(horizontal: true, vertical: false)

            VStack(alignment: .leading, spacing: 4) {
                Text(goal.name)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)

                Spacer()

                if let timeline = goal.timeline {
                    Text(timeline)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .cardStyle()
    }
}
