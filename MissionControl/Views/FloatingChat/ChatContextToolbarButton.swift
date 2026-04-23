import SwiftUI

/// Liquid-glass pill that surfaces the current chat context. Used as the
/// principal toolbar item on every context-bearing page and inside the
/// floating chat sheet. Tapping reveals context actions (pin, etc).
struct ChatContextToolbarButton: View {
    @Environment(ChatContextStore.self) private var chatContext
    @State private var showingNewGroupAlert = false
    @State private var newGroupName = ""

    var body: some View {
        Menu {
            let page = chatContext.pageContext
            if chatContext.isPinned(page) {
                Button(role: .destructive) {
                    chatContext.togglePinned(page)
                } label: {
                    Label("Unpin Context", systemImage: "pin.slash")
                }
            } else {
                Button {
                    chatContext.togglePinned(page)
                } label: {
                    Label("Pin Context", systemImage: "pin")
                }
            }

            Menu {
                ForEach(chatContext.contextGroups) { group in
                    Button {
                        chatContext.toggleKind(page, inGroup: group.id)
                    } label: {
                        if chatContext.isKind(page, inGroup: group.id) {
                            Label(group.name, systemImage: "checkmark")
                        } else {
                            Label(group.name, systemImage: group.icon)
                        }
                    }
                }
                if !chatContext.contextGroups.isEmpty {
                    Divider()
                }
                Button {
                    newGroupName = ""
                    showingNewGroupAlert = true
                } label: {
                    Label("New Group…", systemImage: "plus")
                }
            } label: {
                Label("Add to Context Group", systemImage: "point.3.connected.trianglepath.dotted")
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: chatContext.displayIcon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.blue)

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
        .alert("New Context Group", isPresented: $showingNewGroupAlert) {
            TextField("Name", text: $newGroupName)
            Button("Cancel", role: .cancel) {}
            Button("Create") {
                let trimmed = newGroupName.trimmingCharacters(in: .whitespaces)
                guard !trimmed.isEmpty else { return }
                let group = chatContext.createGroup(name: trimmed)
                chatContext.toggleKind(chatContext.pageContext, inGroup: group.id)
            }
        } message: {
            Text("Create a new group and add “\(chatContext.displayLabel)” to it.")
        }
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
    /// Adds the context pill as a toolbar item. Defaults to `.topBarLeading`
    /// to keep the trailing edge free for page-specific actions. The floating
    /// chat sheet overrides with `.principal` so the pill sits centered.
    /// Pair with `.navigationBarTitleDisplayMode(.inline)` and drop any
    /// `navigationTitle` — the pill replaces the title.
    func chatContextToolbar(placement: ToolbarItemPlacement = .topBarLeading) -> some View {
        modifier(ChatContextToolbarModifier(placement: placement))
    }
}

private struct ChatContextToolbarModifier: ViewModifier {
    let placement: ToolbarItemPlacement

    func body(content: Content) -> some View {
        content
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: placement) {
                    ChatContextToolbarButton()
                }
            }
    }
}
