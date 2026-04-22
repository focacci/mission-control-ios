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
                if chatContext.isLocked {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 32, height: 32)
                    Image(systemName: "lock.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                } else {
                    Image(systemName: "lock.open")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.red)
                        .frame(width: 32, height: 32)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(chatContext.isLocked ? "Unlock chat" : "Lock chat")
        .accessibilityAddTraits(.isButton)
    }
}
