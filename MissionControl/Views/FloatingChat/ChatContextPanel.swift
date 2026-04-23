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
    @State private var expandedGroups: Set<ContextGroup.ID> = []

    var body: some View {
        // Wrapped in a ScrollView so scroll gestures are consumed inside the
        // panel rather than bubbling up to the sheet's interactive dismiss.
        // `basedOnSize` keeps short content from bouncing; the maxHeight caps
        // how much of the sheet the panel can cover when both sections expand.
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
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

    /// Always-visible row for the page the user is looking at. Exposes add
    /// and pin toggles directly on the card so the most common action is one
    /// tap away; the card itself stays put regardless of selection state and
    /// the duplicate in the Selected / Pinned sections below is filtered out.
    private var currentSection: some View {
        let page = chatContext.pageContext
        return VStack(alignment: .leading, spacing: 8) {
            sectionLabel("Current")
            ContextCard(
                icon: chatContext.displayIcon,
                title: chatContext.displayLabel,
                subtitle: chatContext.contextTypeName,
                isActive: chatContext.isSelected(page),
                trailing: {
                    AnyView(
                        HStack(spacing: 4) {
                            CardIconButton(
                                systemName: chatContext.isSelected(page) ? "checkmark.circle.fill" : "plus.circle",
                                isActive: chatContext.isSelected(page),
                                accessibilityLabel: chatContext.isSelected(page) ? "Remove from selected" : "Add to selected"
                            ) {
                                chatContext.toggleSelected(page)
                            }
                            CardIconButton(
                                systemName: chatContext.isPinned(page) ? "pin.fill" : "pin",
                                isActive: chatContext.isPinned(page),
                                accessibilityLabel: chatContext.isPinned(page) ? "Unpin" : "Pin"
                            ) {
                                chatContext.togglePinned(page)
                            }
                        }
                    )
                }
            )
        }
    }

    // MARK: - Selected

    /// All selected contexts in selection order. The current page appears
    /// here *in addition to* the always-on-top Current row when it's been
    /// selected — duplication is intentional so the section reflects the full
    /// grounding set.
    private var selectedListed: [ChatContextKind] {
        chatContext.selectedContexts
    }

    private var selectedSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            collapsibleHeader(
                title: "Selected",
                count: selectedListed.count,
                isExpanded: showSelected
            ) {
                withAnimation(.easeInOut(duration: 0.2)) { showSelected.toggle() }
            }

            if showSelected {
                if selectedListed.isEmpty {
                    emptyRow("No contexts selected yet.")
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

    private var pinnedListed: [ChatContextKind] {
        chatContext.pinnedContexts
    }

    private var pinnedSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            collapsibleHeader(
                title: "Pinned",
                count: pinnedListed.count,
                isExpanded: showPinned
            ) {
                withAnimation(.easeInOut(duration: 0.2)) { showPinned.toggle() }
            }

            if showPinned {
                if pinnedListed.isEmpty {
                    emptyRow("Pin a page's context from its toolbar pill to keep it one tap away.")
                } else {
                    VStack(spacing: 8) {
                        ForEach(Array(pinnedListed.enumerated()), id: \.offset) { _, kind in
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
        VStack(alignment: .leading, spacing: 8) {
            collapsibleHeader(
                title: "Saved Groups",
                count: chatContext.contextGroups.count,
                isExpanded: showSavedGroups
            ) {
                withAnimation(.easeInOut(duration: 0.2)) { showSavedGroups.toggle() }
            }

            if showSavedGroups {
                if chatContext.contextGroups.isEmpty {
                    emptyRow("No saved groups yet. Create one from the Context Groups page or from any page's context pill.")
                } else {
                    VStack(spacing: 8) {
                        ForEach(chatContext.contextGroups) { group in
                            savedGroupRow(group)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func savedGroupRow(_ group: ContextGroup) -> some View {
        let isExpanded = expandedGroups.contains(group.id)
        let isFullySelected = chatContext.isGroupFullySelected(group.id)

        VStack(spacing: 6) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    if isExpanded {
                        expandedGroups.remove(group.id)
                    } else {
                        expandedGroups.insert(group.id)
                    }
                }
            } label: {
                ContextCard(
                    icon: group.icon,
                    title: group.name,
                    subtitle: "\(group.members.count) context\(group.members.count == 1 ? "" : "s")",
                    isActive: isFullySelected,
                    trailing: {
                        AnyView(
                            HStack(spacing: 4) {
                                CardIconButton(
                                    systemName: isFullySelected ? "checkmark.circle.fill" : "plus.circle",
                                    isActive: isFullySelected,
                                    accessibilityLabel: isFullySelected ? "Remove group from selected" : "Add whole group to selected"
                                ) {
                                    chatContext.toggleGroupSelected(group.id)
                                }
                                Image(systemName: "chevron.down")
                                    .font(.footnote.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                    .rotationEffect(.degrees(isExpanded ? 180 : 0))
                                    .frame(width: 28, height: 28)
                            }
                        )
                    }
                )
            }
            .buttonStyle(.plain)

            if isExpanded {
                if group.members.isEmpty {
                    emptyRow("This group has no contexts yet.")
                        .padding(.leading, 16)
                } else {
                    VStack(spacing: 6) {
                        ForEach(group.members) { member in
                            let isSelected = chatContext.isSelected(member.kind)
                            Button {
                                chatContext.toggleSelected(member.kind)
                            } label: {
                                ContextCard(
                                    icon: member.icon,
                                    title: member.label,
                                    subtitle: chatContext.typeName(for: member.kind),
                                    isActive: isSelected
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.leading, 16)
                }
            }
        }
    }

    // MARK: - Building blocks

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.secondary)
    }

    private func collapsibleHeader(
        title: String,
        count: Int,
        isExpanded: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
                sectionLabel(title)
                Text("\(count)")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
                Spacer()
            }
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func emptyRow(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
    }
}

// MARK: - Context Card

private struct ContextCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let isActive: Bool
    var trailing: () -> AnyView = { AnyView(EmptyView()) }

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

            trailing()
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

// MARK: - Card Icon Button

/// Circular tap target sized for comfortable touch on the trailing edge of a
/// context card. `isActive` drives the filled accent treatment that doubles
/// as a status indicator (selected / pinned / fully-added group).
private struct CardIconButton: View {
    let systemName: String
    let isActive: Bool
    let accessibilityLabel: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(isActive ? Color.accentColor : .secondary)
                .frame(width: 32, height: 32)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }
}
