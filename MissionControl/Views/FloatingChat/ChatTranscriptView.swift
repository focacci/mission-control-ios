import SwiftUI

/// Read-only transcript of a persisted chat session. Reached from the
/// "Past chats" section of a detail view (task / goal / initiative / agent).
/// Useful for reviewing what the agent said without starting a new turn.
struct ChatTranscriptView: View {
    let session: ChatSession

    @State private var messages: [ChatTranscriptMessage] = []
    @State private var isLoading = false
    @State private var error: String?

    var body: some View {
        Group {
            if isLoading && messages.isEmpty {
                ProgressView("Loading…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if messages.isEmpty {
                ContentUnavailableView(
                    "Empty",
                    systemImage: "bubble.left.and.bubble.right",
                    description: Text("This session has no messages.")
                )
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 16) {
                        ForEach(messages) { msg in
                            TranscriptBubble(message: msg)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
            }
        }
        .navigationTitle(session.displayTitle)
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .refreshable { await load() }
        .errorAlert(message: $error)
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            messages = try await APIClient.shared.chatMessages(
                sessionId: session.id,
                limit: 500
            )
        } catch {
            self.error = error.localizedDescription
        }
    }
}

private struct TranscriptBubble: View {
    let message: ChatTranscriptMessage

    private var isUser: Bool { message.role == .user }

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if isUser { Spacer(minLength: 52) }

            Text(LocalizedStringKey(message.content))
                .font(.body)
                .foregroundStyle(isUser ? .white : .primary)
                .multilineTextAlignment(.leading)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    isUser
                        ? AnyShapeStyle(Color.blue)
                        : AnyShapeStyle(Material.regularMaterial),
                    in: RoundedRectangle(cornerRadius: 18)
                )
                .frame(maxWidth: .infinity, alignment: isUser ? .trailing : .leading)

            if !isUser { Spacer(minLength: 52) }
        }
    }
}
