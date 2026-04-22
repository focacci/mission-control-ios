import SwiftUI

/// Drop-down panel shown beneath the floating chat's toolbar when the user
/// taps the context picker button. Stacks the current context on top of
/// collapsible sections for pinned contexts and saved context groups.
///
/// Pinned and saved-group data are mocked for now — real persistence lands
/// with the backend work tracked separately.
struct ChatContextPanel: View {
    @Environment(ChatContextStore.self) private var chatContext
    @Binding var isExpanded: Bool

    @State private var showPinned: Bool = false
    @State private var showSavedGroups: Bool = false

    // Mocked until we wire real pinning. These reuse the contexts that used
    // to live in the picker menu so the panel is still functionally useful.
    private static let mockPinned: [ChatContextKind] = [
        .home,
        .agents,
        .plans(section: "All"),
        .schedule(date: Date(), mode: .day),
        .health(section: "Overview"),
        .faith(section: "Overview")
    ]

    private static let mockSavedGroups: [MockGroup] = [
        MockGroup(name: "Morning Review", icon: "sun.max", count: 3),
        MockGroup(name: "Weekly Planning", icon: "calendar.badge.clock", count: 5)
    ]

    var body: some View {
        // Wrapped in a ScrollView so scroll gestures are consumed inside the
        // panel rather than bubbling up to the sheet's interactive dismiss.
        // `basedOnSize` keeps short content from bouncing; the maxHeight caps
        // how much of the sheet the panel can cover when both sections expand.
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                currentSection
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

    private var currentSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionHeader("Current")
            ContextCard(
                icon: chatContext.displayIcon,
                title: chatContext.displayLabel,
                subtitle: chatContext.contextTypeName,
                isActive: true
            )
        }
    }

    // MARK: - Pinned

    private var pinnedSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            collapsibleHeader(
                title: "Pinned",
                count: Self.mockPinned.count,
                isExpanded: showPinned
            ) {
                withAnimation(.easeInOut(duration: 0.2)) { showPinned.toggle() }
            }

            if showPinned {
                VStack(spacing: 8) {
                    ForEach(Array(Self.mockPinned.enumerated()), id: \.offset) { _, kind in
                        Button {
                            chatContext.context = kind
                            withAnimation(.easeInOut(duration: 0.2)) {
                                isExpanded = false
                            }
                        } label: {
                            ContextCard(
                                icon: icon(for: kind),
                                title: label(for: kind),
                                subtitle: typeName(for: kind),
                                isActive: false
                            )
                        }
                        .buttonStyle(.plain)
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
                count: Self.mockSavedGroups.count,
                isExpanded: showSavedGroups
            ) {
                withAnimation(.easeInOut(duration: 0.2)) { showSavedGroups.toggle() }
            }

            if showSavedGroups {
                VStack(spacing: 8) {
                    ForEach(Self.mockSavedGroups) { group in
                        ContextCard(
                            icon: group.icon,
                            title: group.name,
                            subtitle: "\(group.count) contexts",
                            isActive: false
                        )
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

    // MARK: - Label helpers (mirrors the old menu)

    private func label(for kind: ChatContextKind) -> String {
        switch kind {
        case .app:      return "Mission Control"
        case .home:     return "Home"
        case .agents:   return "Agents"
        case .plans:    return "Plans"
        case .schedule: return "Today"
        case .health:   return "Health"
        case .faith:    return "Faith"
        default:        return kind.contextType.capitalized
        }
    }

    private func icon(for kind: ChatContextKind) -> String {
        switch kind {
        case .app:      return "cpu"
        case .home:     return "house"
        case .agents:   return "person.2.wave.2"
        case .plans:    return "list.bullet"
        case .schedule: return "calendar"
        case .health:   return "heart"
        case .faith:    return "cross"
        default:        return "circle"
        }
    }

    private func typeName(for kind: ChatContextKind) -> String {
        switch kind {
        case .app:          return "App"
        case .home:         return "Home"
        case .agents:       return "Agents"
        case .plans:        return "Plans"
        case .schedule:     return "Schedule"
        case .health:       return "Health"
        case .faith:        return "Faith"
        default:            return kind.contextType.capitalized
        }
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

// MARK: - Mock Model

private struct MockGroup: Identifiable {
    let id = UUID()
    let name: String
    let icon: String
    let count: Int
}
