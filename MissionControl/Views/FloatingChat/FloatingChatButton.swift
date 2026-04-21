import SwiftUI

struct FloatingChatButton: View {
    @Binding var isPresented: Bool
    @Environment(ChatContextStore.self) private var chatContext

    var body: some View {
        Button {
            isPresented = true
        } label: {
            ZStack(alignment: .bottomLeading) {
                ZStack {
                    Circle()
                        .fill(.blue.gradient)
                        .frame(width: 56, height: 56)
                        .shadow(color: .blue.opacity(0.2), radius: 4, y: 2)

                    Image(systemName: "bubble.right")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(.white)
                }

                if chatContext.isLocked {
                    ZStack {
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 20, height: 20)

                        Image(systemName: "lock.fill")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    .offset(x: 0, y: 0)
                    .accessibilityLabel("Chat locked")
                }
            }
        }
        .buttonStyle(.plain)
    }
}

extension View {
    @ViewBuilder
    func floatingChatButton(isPresented: Binding<Bool>?) -> some View {
        if let isPresented {
            safeAreaInset(edge: .bottom, spacing: 0) {
                HStack {
                    Spacer()
                    FloatingChatButton(isPresented: isPresented)
                }
                .padding(.trailing, 20)
                .padding(.vertical, 12)
            }
        } else {
            self
        }
    }
}
