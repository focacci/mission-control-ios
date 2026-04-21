import SwiftUI

/// Ephemeral floating chat sheet. Opens from the global bubble button. The
/// center-toolbar context button surfaces the current grounding surface and
/// (eventually) becomes the entry point for pinning and cross-page
/// navigation within context groups. For the dedicated agent chat page,
/// see `AgentChatView`.
struct ChatView: View {
    @Environment(ChatContextStore.self) private var chatContext

    var body: some View {
        ChatConversationView(
            useDefaultAgent: true,
            welcomeMessage: { chatContext.welcomeMessage }
        )
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                ChatContextToolbarButton()
            }
        }
    }
}

// MARK: - Context Toolbar Button

private struct ChatContextToolbarButton: View {
    @Environment(ChatContextStore.self) private var chatContext

    var body: some View {
        Menu {
            Button {
                // TODO: wire up pinning once the context group model lands.
            } label: {
                Label("Pin Context", systemImage: "pin")
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: chatContext.displayIcon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.blue)

                VStack(alignment: .leading, spacing: 1) {
                    Text(chatContext.contextTypeName.uppercased())
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.blue.opacity(0.75))
                        .tracking(0.8)

                    Text(chatContext.displayLabel)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                }

                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .modifier(LiquidGlassContextButtonBackground())
        }
        .accessibilityLabel("\(chatContext.contextTypeName) context: \(chatContext.displayLabel)")
        .accessibilityHint("Opens context actions")
    }
}

private struct LiquidGlassContextButtonBackground: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.glassEffect(.regular.interactive(), in: .capsule)
        } else {
            content.background(.regularMaterial, in: Capsule())
        }
    }
}
