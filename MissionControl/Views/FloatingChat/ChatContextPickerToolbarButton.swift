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
            ZStack {
                Image(systemName: iconName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(hasContext ? Color.blue : .secondary)
                    .frame(width: 32, height: 32)
            }
        }
        .accessibilityLabel("Chat context: \(chatContext.contextTypeName) \(chatContext.displayLabel)")
        .accessibilityHint(isExpanded ? "Hides context panel" : "Shows context panel")
    }
}
