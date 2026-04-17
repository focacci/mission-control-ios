import SwiftUI

struct GoalCard: View {
    let goal: Goal

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(goal.emoji)
                    .font(.system(size: 36))
                Spacer()
                Circle()
                    .fill(goal.focusColor)
                    .frame(width: 10, height: 10)
            }

            Text(goal.name)
                .font(.headline)
                .lineLimit(2)
                .minimumScaleFactor(0.85)

            HStack {
                Text(goal.focusLabel)
                    .font(.caption)
                    .foregroundStyle(goal.focusColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(goal.focusColor.opacity(0.15), in: Capsule())

                Spacer()

                if let initiatives = goal.initiatives {
                    Label("\(initiatives.count)", systemImage: "list.bullet")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.12), radius: 6, x: 0, y: 3)
    }
}
