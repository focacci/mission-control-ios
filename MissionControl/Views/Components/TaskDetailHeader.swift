import SwiftUI

struct TaskDetailHeader: View {
    let task: MCTask

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(task.name)
                .font(.title2)
                .fontWeight(.bold)
                .multilineTextAlignment(.leading)

            if task.goal != nil || task.initiative != nil {
                HStack(spacing: 8) {
                    if let goal = task.goal {
                        Text("\(goal.emoji) \(goal.name)")
                            .font(.subheadline)
                            .lineLimit(1)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(.clear, in: Capsule())
                            .overlay(Capsule().strokeBorder(.secondary.opacity(0.4), lineWidth: 1))
                    }

                    if let initiative = task.initiative {
                        Text("\(initiative.emoji) \(initiative.name)")
                            .font(.subheadline)
                            .lineLimit(1)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(.clear, in: Capsule())
                            .overlay(Capsule().strokeBorder(.secondary.opacity(0.4), lineWidth: 1))
                    }

                    Spacer()
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}
