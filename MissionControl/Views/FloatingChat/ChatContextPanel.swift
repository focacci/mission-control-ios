import SwiftUI

/// Drop-down panel shown beneath the floating chat's toolbar when the user
/// taps the context picker button. Stacks the current context on top of
/// collapsible sections for the user's selected contexts, pinned contexts,
/// and saved context groups.
struct ChatContextPanel: View {
    @Environment(ChatContextStore.self) private var chatContext
    @Binding var isExpanded: Bool

    @State private var showSelected: Bool = true
    @State private var showPinned: Bool = true
    @State private var showSavedGroups: Bool = false

    var body: some View {
        // Wrapped in a ScrollView so scroll gestures are consumed inside the
        // panel rather than bubbling up to the sheet's interactive dismiss.
        // `basedOnSize` keeps short content from bouncing; the maxHeight caps
        // how much of the sheet the panel can cover when both sections expand.
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                currentSection
                selectedSection
                pinnedSection
                savedGroupsSection
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollBounceBehavior(.basedOnSize)
        .frame(maxHeight: 420)
        .background(.bar)
        .overlay(alignment: .bottom) {
            Divider()
        }
    }

    // MARK: - Current

    private var isCurrentSelected: Bool {
        chatContext.isSelected(chatContext.pageContext)
    }

    /// Hidden once the current context is selected — it then appears at the
    /// top of the Selected section instead.
    @ViewBuilder
    private var currentSection: some View {
        if !isCurrentSelected {
            let page = chatContext.pageContext
            VStack(alignment: .leading, spacing: 6) {
                sectionHeader("Current")
                Button {
                    chatContext.toggleSelected(page)
                } label: {
                    ContextCard(
                        icon: chatContext.displayIcon,
                        title: chatContext.displayLabel,
                        subtitle: chatContext.contextTypeName,
                        isActive: false
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Selected

    /// Selected contexts for the Selected section. When the current page
    /// context is selected, it's pinned to the top; other selections follow
    /// in selection order.
    private var selectedListed: [ChatContextKind] {
        let page = chatContext.pageContext
        let rest = chatContext.selectedContexts.filter { $0 != page }
        return isCurrentSelected ? [page] + rest : rest
    }

    private var selectedSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            collapsibleHeader(
                title: "Selected",
                count: selectedListed.count,
                isExpanded: showSelected
            ) {
                withAnimation(.easeInOut(duration: 0.2)) { showSelected.toggle() }
            }

            if showSelected {
                if selectedListed.isEmpty {
                    Text("No contexts selected yet.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                } else {
                    VStack(spacing: 8) {
                        ForEach(Array(selectedListed.enumerated()), id: \.offset) { _, kind in
                            Button {
                                chatContext.toggleSelected(kind)
                            } label: {
                                ContextCard(
                                    icon: chatContext.icon(for: kind),
                                    title: chatContext.label(for: kind),
                                    subtitle: chatContext.typeName(for: kind),
                                    isActive: true
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Pinned

    private var pinnedSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            collapsibleHeader(
                title: "Pinned",
                count: chatContext.pinnedContexts.count,
                isExpanded: showPinned
            ) {
                withAnimation(.easeInOut(duration: 0.2)) { showPinned.toggle() }
            }

            if showPinned {
                if chatContext.pinnedContexts.isEmpty {
                    Text("Pin a page's context from its toolbar pill to keep it one tap away.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                } else {
                    VStack(spacing: 8) {
                        ForEach(Array(chatContext.pinnedContexts.enumerated()), id: \.offset) { _, kind in
                            Button {
                                chatContext.toggleSelected(kind)
                            } label: {
                                ContextCard(
                                    icon: chatContext.icon(for: kind),
                                    title: chatContext.label(for: kind),
                                    subtitle: chatContext.typeName(for: kind),
                                    isActive: chatContext.isSelected(kind)
                                )
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button(role: .destructive) {
                                    chatContext.unpin(kind)
                                } label: {
                                    Label("Unpin", systemImage: "pin.slash")
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Saved Groups

    private var savedGroupsSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            collapsibleHeader(
                title: "Saved Groups",
                count: chatContext.contextGroups.count,
                isExpanded: showSavedGroups
            ) {
                withAnimation(.easeInOut(duration: 0.2)) { showSavedGroups.toggle() }
            }

            if showSavedGroups {
                if chatContext.contextGroups.isEmpty {
                    Text("No saved groups yet. Create one from the Context Groups page or from any page's context pill.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                } else {
                    VStack(spacing: 8) {
                        ForEach(chatContext.contextGroups) { group in
                            ContextCard(
                                icon: group.icon,
                                title: group.name,
                                subtitle: "\(group.members.count) contexts",
                                isActive: false
                            )
                        }
                    }
                }
            }
        }
    }

    // MARK: - Building blocks

    private func sectionHeader(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.secondary)
            .tracking(0.5)
    }

    private func collapsibleHeader(
        title: String,
        count: Int,
        isExpanded: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
                sectionHeader(title)
                Text("\(count)")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.tertiary)
                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

}

// MARK: - Context Card

private struct ContextCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let isActive: Bool

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(isActive ? Color.accentColor.opacity(0.18) : Color(.systemGray5))
                    .frame(width: 32, height: 32)
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(isActive ? Color.accentColor : .secondary)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            if isActive {
                Image(systemName: "checkmark")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.accentColor)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(isActive ? Color.accentColor.opacity(0.4) : Color.clear, lineWidth: 1)
        )
    }
}

