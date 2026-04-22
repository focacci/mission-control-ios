import SwiftUI

/// Circular icon button that toggles the chat context panel below the
/// floating chat's toolbar. The panel itself (`ChatContextPanel`) is hosted
/// by `ChatView` so it can render inside the sheet's safe-area inset rather
/// than inside the toolbar.
struct ChatContextPickerToolbarButton: View {
    @Environment(ChatContextStore.self) private var chatContext
    @Binding var isExpanded: Bool

    var body: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                isExpanded.toggle()
            }
        } label: {
            let hasContext = chatContext.isContextActive
            let iconName = hasContext
                ? "point.3.filled.connected.trianglepath.dotted"
                : "point.3.connected.trianglepath.dotted"
            Image(systemName: iconName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(iconTint(hasContext: hasContext))
                .frame(width: 32, height: 32)
                .background(chipBackground)
                .overlay(chipStroke)
                .scaleEffect(isExpanded ? 0.96 : 1.0)
                .animation(.easeInOut(duration: 0.2), value: isExpanded)
        }
        .accessibilityLabel("Chat context: \(chatContext.contextTypeName) \(chatContext.displayLabel)")
        .accessibilityHint(isExpanded ? "Hides context panel" : "Shows context panel")
    }

    private func iconTint(hasContext: Bool) -> Color {
        if isExpanded { return .accentColor }
        return hasContext ? .blue : .secondary
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
}
