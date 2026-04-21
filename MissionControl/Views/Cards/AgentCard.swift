import SwiftUI

struct AgentCard: View {
    let agent: Agent
    var activity: AgentActivity? = nil

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(.blue.opacity(0.12))
                    .frame(width: 44, height: 44)
                Text(agent.displayEmoji)
                    .font(.title3)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(agent.displayName)
                        .font(.headline)
                    if agent.isDefault {
                        Text("DEFAULT")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(.blue)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.blue.opacity(0.15), in: Capsule())
                    }
                }

                Text("id: \(agent.id)")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let model = agent.model, !model.isEmpty {
                    Label(model, systemImage: "cpu")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                if let activity, activity.chatCount > 0 {
                    HStack(spacing: 10) {
                        Label("\(activity.chatCount) chat\(activity.chatCount == 1 ? "" : "s")",
                              systemImage: "bubble.left.and.text.bubble.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        if let last = activity.lastMessageAt {
                            Text("· last \(relativeTime(last))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                if let prompt = agent.systemPrompt, !prompt.isEmpty {
                    Text(prompt)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .padding(.top, 2)
                }
            }

            Spacer(minLength: 0)
        }
        .cardStyle()
    }

    private func relativeTime(_ iso: String) -> String {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let date = f.date(from: iso) ?? ISO8601DateFormatter().date(from: iso) ?? Date()
        let rel = RelativeDateTimeFormatter()
        rel.unitsStyle = .short
        return rel.localizedString(for: date, relativeTo: Date())
    }
}
