import SwiftUI

/// Circular icon button that toggles the agent picker panel below the
/// floating chat's toolbar. Mirrors `ChatContextPickerToolbarButton`; the
/// panel itself (`ChatAgentPanel`) is hosted by `ChatView`. The icon
/// reflects the live `agentConnectionState` on the context store.
struct ChatAgentPickerToolbarButton: View {
    @Environment(ChatContextStore.self) private var chatContext
    @Binding var isExpanded: Bool

    @State private var pulse: Bool = false

    var body: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                isExpanded.toggle()
            }
        } label: {
            Image(systemName: iconName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(iconColor)
                .frame(width: 32, height: 32)
                .opacity(chatContext.agentConnectionState == .connecting && pulse ? 0.35 : 1.0)
                .background(chipBackground)
                .overlay(chipStroke)
                .scaleEffect(isExpanded ? 0.96 : 1.0)
                .animation(.easeInOut(duration: 0.2), value: isExpanded)
        }
        .onAppear { startPulseIfNeeded() }
        .onChange(of: chatContext.agentConnectionState) { _, _ in
            startPulseIfNeeded()
        }
        .accessibilityLabel("Agent: \(chatContext.selectedAgentName ?? "Intella") · \(accessibilityState)")
        .accessibilityHint(isExpanded ? "Hides agent picker" : "Shows agent picker")
    }

    private var iconName: String {
        switch chatContext.agentConnectionState {
        case .connecting: return "person.wave.2"
        case .connected:  return "person.wave.2.fill"
        case .offline:    return "person.slash"
        }
    }

    private var iconColor: Color {
        switch chatContext.agentConnectionState {
        case .connecting: return .yellow
        case .connected:  return .green
        case .offline:    return .gray
        }
    }

    private var accessibilityState: String {
        switch chatContext.agentConnectionState {
        case .connecting: return "connecting"
        case .connected:  return "connected"
        case .offline:    return "offline"
        }
    }

    private var chipBackground: some View {
        Circle()
            .fill(isExpanded
                  ? Color.accentColor.opacity(0.18)
                  : Color.secondary.opacity(0.12))
    }

    private var chipStroke: some View {
        Circle()
            .strokeBorder(
                isExpanded ? Color.accentColor.opacity(0.5) : Color.clear,
                lineWidth: 1
            )
    }

    private func startPulseIfNeeded() {
        guard chatContext.agentConnectionState == .connecting else {
            pulse = false
            return
        }
        pulse = false
        withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
            pulse = true
        }
    }
}
