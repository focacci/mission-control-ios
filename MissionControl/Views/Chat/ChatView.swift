import SwiftUI

// MARK: - Data

struct ChatMessage: Identifiable {
    let id = UUID()
    let role: Role
    let content: String

    enum Role { case user, agent }
}

// MARK: - Chat Sheet

struct ChatView: View {
    @Environment(ChatContextStore.self) private var chatContext

    @State private var messages: [ChatMessage] = []
    @State private var inputText = ""
    @FocusState private var isInputFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            contextChip
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 12)

            Divider()

            messageList

            Divider()

            inputBar
        }
        .onAppear {
            messages = [ChatMessage(role: .agent, content: chatContext.welcomeMessage)]
        }
        .onChange(of: chatContext.context) {
            messages = [ChatMessage(role: .agent, content: chatContext.welcomeMessage)]
            inputText = ""
        }
    }

    // MARK: - Context Chip

    private var contextChip: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(.blue.opacity(0.12))
                    .frame(width: 36, height: 36)

                if let emoji = chatContext.displayEmoji {
                    Text(emoji)
                        .font(.system(size: 18))
                } else {
                    Image(systemName: chatContext.displayIcon)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.blue)
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(chatContext.contextTypeName.uppercased())
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.blue.opacity(0.7))
                    .tracking(0.8)

                Text(chatContext.displayLabel)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
            }

            Spacer()

            Label("context", systemImage: "scope")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .labelStyle(.iconOnly)
                .padding(6)
                .background(.quaternary, in: Circle())
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.blue.opacity(0.06), in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(.blue.opacity(0.18), lineWidth: 1)
        )
    }

    // MARK: - Message List

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    ForEach(messages) { message in
                        MessageBubble(message: message)
                            .id(message.id)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .onChange(of: messages.count) {
                if let last = messages.last {
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
        }
    }

    // MARK: - Input Bar

    private var inputBar: some View {
        HStack(alignment: .bottom, spacing: 10) {
            TextField("Ask anything…", text: $inputText, axis: .vertical)
                .lineLimit(1...5)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22))
                .focused($isInputFocused)

            Button(action: sendMessage) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.secondary : .blue)
            }
            .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .animation(.easeInOut(duration: 0.15), value: inputText.isEmpty)
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        inputText = ""
        messages.append(ChatMessage(role: .user, content: text))

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            messages.append(ChatMessage(
                role: .agent,
                content: "Got it. (Agent responses will be live once the backend is wired up.)"
            ))
        }
    }
}

// MARK: - Message Bubble

struct MessageBubble: View {
    let message: ChatMessage

    var isUser: Bool { message.role == .user }

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if !isUser {
                agentAvatar
            } else {
                Spacer(minLength: 52)
            }

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

            if isUser {
                Spacer(minLength: 0)
                    .frame(width: 0)
            }
        }
    }

    private var agentAvatar: some View {
        ZStack {
            Circle()
                .fill(.blue.gradient)
                .frame(width: 28, height: 28)
            Image(systemName: "cpu")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white)
        }
    }
}
