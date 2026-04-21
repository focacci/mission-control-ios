import SwiftUI

/// Ephemeral floating chat sheet. Opens from the global bubble button and
/// shows a context chip so the user always knows what surface the assistant
/// is grounded in. For the dedicated agent chat page, see `AgentChatView`.
struct ChatView: View {
    @Environment(ChatContextStore.self) private var chatContext

    var body: some View {
        VStack(spacing: 0) {
            ChatContextChip()
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 12)

            Divider()

            ChatConversationView(
                useDefaultAgent: true,
                welcomeMessage: { chatContext.welcomeMessage }
            )
        }
        .navigationTitle("Chat")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Context Chip

private struct ChatContextChip: View {
    @Environment(ChatContextStore.self) private var chatContext

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(.blue.opacity(0.12))
                    .frame(width: 36, height: 36)

                Image(systemName: chatContext.displayIcon)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.blue)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(chatContext.contextTypeName.uppercased())
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.blue.opacity(0.7))
                    .tracking(0.8)

                Text(chatContext.displayLabel)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
            }

            Spacer()

            Label("context", systemImage: "scope")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .labelStyle(.iconOnly)
                .padding(6)
                .background(.quaternary, in: Circle())
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.blue.opacity(0.06), in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(.blue.opacity(0.18), lineWidth: 1)
        )
    }
}
