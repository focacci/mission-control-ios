import SwiftUI

/// Circular icon button that toggles the agent picker panel below the
/// floating chat's toolbar. Mirrors `ChatContextPickerToolbarButton`; the
/// panel itself (`ChatAgentPanel`) is hosted by `ChatView`.
struct ChatAgentPickerToolbarButton: View {
    @Environment(ChatContextStore.self) private var chatContext
    @Binding var isExpanded: Bool

    var body: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                isExpanded.toggle()
            }
        } label: {
            ZStack {
                Circle()
                    .fill(isExpanded ? Color.accentColor.opacity(0.2) : Color(.systemGray5))
                    .frame(width: 32, height: 32)

                Image(systemName: "person.wave.2")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(isExpanded ? Color.accentColor : .secondary)
            }
        }
        .accessibilityLabel("Agent: \(chatContext.selectedAgentName ?? "Intella")")
        .accessibilityHint(isExpanded ? "Hides agent picker" : "Shows agent picker")
    }
}
