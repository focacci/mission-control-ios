import SwiftUI

/// Liquid-glass pill that surfaces the current chat context. Used as the
/// principal toolbar item on every context-bearing page and inside the
/// floating chat sheet. Tapping reveals context actions (pin, etc).
struct ChatContextToolbarButton: View {
    @Environment(ChatContextStore.self) private var chatContext

    var body: some View {
        Menu {
            Button {
                // TODO: wire up pinning once the context group model lands.
            } label: {
                Label("Pin Context", systemImage: "pin")
            }
        } label: {
            HStack(spacing: 8) {
                if let emoji = chatContext.displayEmoji {
                    Text(emoji)
                        .font(.system(size: 16))
                } else {
                    Image(systemName: chatContext.displayIcon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.blue)
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text(chatContext.contextTypeName.uppercased())
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.blue.opacity(0.75))
                        .tracking(0.8)
                        .lineLimit(1)

                    Text(chatContext.displayLabel)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }

                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .frame(maxWidth: 220)
            .fixedSize(horizontal: false, vertical: true)
            .modifier(LiquidGlassContextButtonBackground())
        }
        .accessibilityLabel("\(chatContext.contextTypeName) context: \(chatContext.displayLabel)")
        .accessibilityHint("Opens context actions")
    }
}

private struct LiquidGlassContextButtonBackground: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.glassEffect(.regular.interactive(), in: .capsule)
        } else {
            content.background(.regularMaterial, in: Capsule())
        }
    }
}

// MARK: - View Modifier

extension View {
    /// Adds the context pill as a principal (center) toolbar item. Pair with
    /// `.navigationBarTitleDisplayMode(.inline)` and drop any `navigationTitle`
    /// — the pill replaces the title.
    func chatContextToolbar() -> some View {
        modifier(ChatContextToolbarModifier())
    }
}

private struct ChatContextToolbarModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    ChatContextToolbarButton()
                }
            }
    }
}
