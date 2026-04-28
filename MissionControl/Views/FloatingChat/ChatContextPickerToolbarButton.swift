import SwiftUI

/// Capsule pill that toggles the chat context panel below the floating chat's
/// toolbar. Surfaces both the count of selected (grounding) contexts and the
/// count of pinned contexts so the user can see at a glance what the chat is
/// currently grounded on and how many quick-pick contexts are available. The
/// panel itself (`ChatContextPanel`) is hosted by `ChatView` so it can render
/// inside the sheet's safe-area inset rather than inside the toolbar.
struct ChatContextPickerToolbarButton: View {
    @Environment(ChatContextStore.self) private var chatContext
    @Binding var isExpanded: Bool

    var body: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                isExpanded.toggle()
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: contextIconName)
                    .font(.system(size: 16, weight: .semibold))
                Text("\(selectedCount)")
                    .font(.system(size: 16, weight: .semibold))
                    .monospacedDigit()
                separator
                Image(systemName: "pin.fill")
                    .font(.system(size: 13, weight: .semibold))
                Text("\(pinnedCount)")
                    .font(.system(size: 16, weight: .semibold))
                    .monospacedDigit()
            }
            .foregroundStyle(tint)
            .padding(.horizontal, 14)
            .frame(height: 38)
            .background(pillBackground)
            .overlay(pillStroke)
            .scaleEffect(isExpanded ? 0.97 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: isExpanded)
        }
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(isExpanded ? "Hides context panel" : "Shows context panel")
    }

    private var selectedCount: Int { chatContext.selectedContexts.count }
    private var pinnedCount: Int { chatContext.pinnedContexts.count }
    private var hasSelected: Bool { selectedCount > 0 }

    private var contextIconName: String {
        hasSelected
            ? "point.3.filled.connected.trianglepath.dotted"
            : "point.3.connected.trianglepath.dotted"
    }

    private var tint: Color {
        if isExpanded { return .accentColor }
        return hasSelected ? .blue : .secondary
    }

    private var separator: some View {
        Rectangle()
            .fill(Color.secondary.opacity(0.35))
            .frame(width: 1, height: 16)
    }

    private var pillBackground: some View {
        Capsule()
            .fill(isExpanded
                  ? Color.accentColor.opacity(0.18)
                  : Color.secondary.opacity(0.12))
    }

    private var pillStroke: some View {
        Capsule()
            .strokeBorder(
                isExpanded ? Color.accentColor.opacity(0.5) : Color.clear,
                lineWidth: 1
            )
    }

    private var accessibilityLabel: String {
        "Chat context: \(selectedCount) selected, \(pinnedCount) pinned"
    }
}
