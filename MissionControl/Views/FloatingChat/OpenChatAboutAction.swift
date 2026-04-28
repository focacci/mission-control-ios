import SwiftUI

/// Row-level "Open chat about this" affordance — IOS_MESSAGE_PARTS_PLAN §6,
/// build step 9. Drops a context (`task`, `goal`, `initiative`,
/// `agentAssignment`, `brief`) into `selectedContexts` and opens the floating
/// chat sheet so the agent's `current_context` resolves to that entity from
/// the very first turn.
extension ChatContextStore {
    /// Single primary grounding: replace any existing selection with `kind`
    /// so the floating chat doesn't surface stale entities the user picked
    /// from a previous page. Locking is left untouched; if the user has the
    /// chat locked, the new context still wins for the next turn.
    func openChat(about kind: ChatContextKind) {
        selectedContexts = [kind]
        showingChat = true
    }
}

/// Reusable menu/swipe button. Use inside `.contextMenu`, `.swipeActions`, or
/// any `Menu` content where a "chat about this" entry makes sense.
struct OpenChatAboutMenuItem: View {
    @Environment(ChatContextStore.self) private var chatContext
    let kind: ChatContextKind

    var body: some View {
        Button {
            chatContext.openChat(about: kind)
        } label: {
            Label("Open chat about this", systemImage: "bubble.left.and.text.bubble.right")
        }
    }
}

/// Tinted swipe-action variant. `.swipeActions` only renders inside `List`
/// rows — for `LazyVStack`/`ScrollView` rows, use `OpenChatAboutMenuItem`
/// inside a `.contextMenu` instead.
struct OpenChatAboutSwipeButton: View {
    @Environment(ChatContextStore.self) private var chatContext
    let kind: ChatContextKind

    var body: some View {
        Button {
            chatContext.openChat(about: kind)
        } label: {
            Label("Chat", systemImage: "bubble.left.and.text.bubble.right")
        }
        .tint(.blue)
    }
}
