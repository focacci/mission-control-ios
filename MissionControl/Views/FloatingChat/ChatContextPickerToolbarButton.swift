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
            ZStack {
                Circle()
                    .fill(isExpanded ? Color.accentColor.opacity(0.2) : Color(.systemGray5))
                    .frame(width: 32, height: 32)

                Image(systemName: "point.3.filled.connected.trianglepath.dotted")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(isExpanded ? Color.accentColor : .secondary)
            }
        }
        .accessibilityLabel("Chat context: \(chatContext.contextTypeName) \(chatContext.displayLabel)")
        .accessibilityHint(isExpanded ? "Hides context panel" : "Shows context panel")
    }
}
