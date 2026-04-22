import SwiftUI

/// Circular icon button that expands into a list of selectable chat contexts,
/// including the one currently active. Lives next to the lock button in the
/// floating chat's leading toolbar. Replaces the pill-style context button
/// that used to display the current context inline.
struct ChatContextPickerToolbarButton: View {
    @Environment(ChatContextStore.self) private var chatContext

    private static let switchable: [ChatContextKind] = [
        .app,
        .home,
        .agents,
        .plans(section: "All"),
        .schedule(date: Date(), mode: .day),
        .health(section: "Overview"),
        .faith(section: "Overview")
    ]

    var body: some View {
        Menu {
            Section("Current") {
                Label(
                    "\(chatContext.contextTypeName) — \(chatContext.displayLabel)",
                    systemImage: chatContext.displayIcon
                )
            }

            Section("Switch To") {
                ForEach(Array(Self.switchable.enumerated()), id: \.offset) { _, kind in
                    Button {
                        chatContext.context = kind
                    } label: {
                        Label(label(for: kind), systemImage: icon(for: kind))
                    }
                }
            }
        } label: {
            ZStack {
                Circle()
                    .fill(Color(.systemGray5))
                    .frame(width: 32, height: 32)

                Image(systemName: "point.3.filled.connected.trianglepath.dotted")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityLabel("Chat context: \(chatContext.contextTypeName) \(chatContext.displayLabel)")
        .accessibilityHint("Shows available contexts")
    }

    private func label(for kind: ChatContextKind) -> String {
        switch kind {
        case .app:      return "Mission Control"
        case .home:     return "Home"
        case .agents:   return "Agents"
        case .plans:    return "Plans"
        case .schedule: return "Schedule"
        case .health:   return "Health"
        case .faith:    return "Faith"
        default:        return kind.contextType.capitalized
        }
    }

    private func icon(for kind: ChatContextKind) -> String {
        switch kind {
        case .app:      return "cpu"
        case .home:     return "house"
        case .agents:   return "person.2.wave.2"
        case .plans:    return "list.bullet"
        case .schedule: return "calendar"
        case .health:   return "heart"
        case .faith:    return "cross"
        default:        return "circle"
        }
    }
}
