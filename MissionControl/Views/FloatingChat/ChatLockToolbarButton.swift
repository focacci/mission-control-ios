import SwiftUI

/// Toggles the floating chat's locked state. Lives as the principal toolbar
/// item in the floating chat sheet. Lock state is stored on
/// `ChatContextStore` so it survives sheet dismissals.
struct ChatLockToolbarButton: View {
    @Environment(ChatContextStore.self) private var chatContext

    var body: some View {
        Button {
            chatContext.isLocked.toggle()
        } label: {
            ZStack {
                Circle()
                    .fill(chatContext.isLocked ? Color.blue : Color(.systemGray5))
                    .frame(width: 32, height: 32)

                Image(systemName: chatContext.isLocked ? "lock.fill" : "lock.open.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(chatContext.isLocked ? .white : .secondary)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(chatContext.isLocked ? "Unlock chat" : "Lock chat")
        .accessibilityAddTraits(.isButton)
    }
}
