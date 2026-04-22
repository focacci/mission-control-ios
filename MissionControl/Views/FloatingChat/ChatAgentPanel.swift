import SwiftUI

/// Drop-down panel shown beneath the floating chat's toolbar when the user
/// taps the agent picker button. Lists the available OpenClaw agents; tapping
/// one updates the floating chat's `selectedAgentId` on the context store.
struct ChatAgentPanel: View {
    @Environment(ChatContextStore.self) private var chatContext
    @Binding var isExpanded: Bool

    @State private var viewModel = AgentsViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                currentSection
                availableSection
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollBounceBehavior(.basedOnSize)
        .frame(maxHeight: 420)
        .background(.bar)
        .overlay(alignment: .bottom) {
            Divider()
        }
        .task {
            if viewModel.agents.isEmpty {
                await viewModel.load()
            }
        }
    }

    // MARK: - Current

    private var currentSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionHeader("Current")
            AgentPickerCard(
                emoji: chatContext.selectedAgentEmoji ?? "🤖",
                title: chatContext.selectedAgentName ?? "Intella",
                subtitle: chatContext.selectedAgentId == nil ? "Default agent" : "Selected",
                isActive: true
            )
        }
    }

    // MARK: - Available

    private var availableSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionHeader("Agents")

            if viewModel.isLoading && viewModel.agents.isEmpty {
                HStack {
                    ProgressView()
                    Text("Loading agents…")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 8)
            } else if viewModel.agents.isEmpty {
                Text(viewModel.error ?? "No agents yet.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
            } else {
                VStack(spacing: 8) {
                    ForEach(viewModel.agents) { agent in
                        Button {
                            select(agent)
                        } label: {
                            AgentPickerCard(
                                emoji: agent.displayEmoji,
                                title: agent.displayName,
                                subtitle: subtitle(for: agent),
                                isActive: isSelected(agent)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private func isSelected(_ agent: Agent) -> Bool {
        if let id = chatContext.selectedAgentId {
            return agent.id == id
        }
        return agent.isDefault
    }

    private func subtitle(for agent: Agent) -> String {
        if let model = agent.model, !model.isEmpty {
            return agent.isDefault ? "Default · \(model)" : model
        }
        return agent.isDefault ? "Default" : "Agent"
    }

    private func select(_ agent: Agent) {
        chatContext.selectedAgentId = agent.isDefault ? nil : agent.id
        chatContext.selectedAgentName = agent.displayName
        chatContext.selectedAgentEmoji = agent.displayEmoji
        withAnimation(.easeInOut(duration: 0.2)) {
            isExpanded = false
        }
    }

    private func sectionHeader(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.secondary)
            .tracking(0.5)
    }
}

// MARK: - Agent Picker Card

private struct AgentPickerCard: View {
    let emoji: String
    let title: String
    let subtitle: String
    let isActive: Bool

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(isActive ? Color.accentColor.opacity(0.18) : Color(.systemGray5))
                    .frame(width: 32, height: 32)
                Text(emoji)
                    .font(.system(size: 16))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            if isActive {
                Image(systemName: "checkmark")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.accentColor)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(isActive ? Color.accentColor.opacity(0.4) : Color.clear, lineWidth: 1)
        )
    }
}
