import SwiftUI

struct GoalDetailHeader: View {
    let goal: Goal

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text(goal.emoji)
                    .font(.system(size: 56))

                Text(goal.name)
                    .font(.title2)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.leading)

                Spacer()
            }

            HStack(spacing: 12) {
                Label(goal.focusLabel, systemImage: "circle.fill")
                    .font(.subheadline)
                    .foregroundStyle(goal.focusColor)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 6)
                    .background(goal.focusColor.opacity(0.15), in: Capsule())

                if let timeline = goal.timeline, !timeline.isEmpty {
                    Label(timeline, systemImage: "calendar")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.secondary.opacity(0.1), in: Capsule())
                }

                Spacer()
            }

            if let story = goal.story, !story.isEmpty {
                Text(story)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}
