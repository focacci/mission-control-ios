import SwiftUI

struct GoalCard: View {
    let goal: Goal

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Left column: icon pinned to top, focus badge pinned to bottom
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

            // Right column: name top-left, timeline bottom-right
            VStack(alignment: .leading, spacing:  4) {
                Text(goal.name)
                    .font(.headline)
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
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.12), radius: 6, x: 0, y: 3)
    }
}
