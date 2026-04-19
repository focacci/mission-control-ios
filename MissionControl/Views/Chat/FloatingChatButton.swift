import SwiftUI

struct FloatingChatButton: View {
    @Binding var isPresented: Bool

    var body: some View {
        Button {
            isPresented = true
        } label: {
            ZStack {
                Circle()
                    .fill(.blue.gradient)
                    .frame(width: 56, height: 56)
                    .shadow(color: .blue.opacity(0.2), radius: 4, y: 2)

                Image(systemName: "bubble.left.and.bubble.right.fill")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(.white)
            }
        }
        .buttonStyle(.plain)
        .padding(.trailing, 20)
        .padding(.bottom, 68)
    }
}
