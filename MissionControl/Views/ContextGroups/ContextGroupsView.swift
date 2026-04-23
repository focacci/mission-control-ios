import SwiftUI

// MARK: - Context Groups Tab Root
//
// System feature for managing saved groups of related chat contexts. A group
// bundles multiple `ChatContextKind` selections (e.g. a goal + its schedule +
// a brief) so the user or agent can ground a chat on several things at once
// without re-picking them every turn. The floating chat's context panel
// surfaces these groups under its "Saved Groups" section; this page is the
// management surface where they're created, reviewed, and curated.
//
// Storage is mocked until the backend lands. Group members reference existing
// contexts by `(contextType, contextId)` — the same pair persisted with chat
// sessions on the API side.

struct ContextGroupsView: View {
    @Environment(ChatContextStore.self) private var chatContext
    @State private var groups: [ContextGroup] = ContextGroup.mocks
    @State private var showingCreate = false

    var body: some View {
        List {
            Section {
                Text("Bundle related contexts from across the app so you — or the agent — can ground a chat on all of them at once.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Pinned") {
                if chatContext.pinnedContexts.isEmpty {
                    Text("Nothing pinned yet. Tap the context pill on any page and choose Pin Context to keep it one tap away.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(Array(chatContext.pinnedContexts.enumerated()), id: \.offset) { _, kind in
                        PinnedContextRow(
                            kind: kind,
                            label: chatContext.label(for: kind),
                            icon: chatContext.icon(for: kind),
                            typeName: chatContext.typeName(for: kind)
                        ) {
                            chatContext.unpin(kind)
                        }
                    }
                }
            }

            Section("Your Groups") {
                if groups.isEmpty {
                    Text("No groups yet. Create one to save a recurring set of contexts.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(groups) { group in
                        ContextGroupRow(group: group)
                    }
                }
            }

            Section("Suggested") {
                ForEach(ContextGroup.suggestions) { suggestion in
                    Button {
                        groups.append(suggestion)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: suggestion.icon)
                                .foregroundStyle(.blue)
                                .frame(width: 24)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(suggestion.name)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.primary)
                                Text(suggestion.summary)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                            Spacer()
                            Image(systemName: "plus.circle")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Context Groups")
        .navigationBarTitleDisplayMode(.inline)
        .chatContext(.contextGroups)
        .chatContextToolbar()
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingCreate = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("New context group")
            }
        }
        .sheet(isPresented: $showingCreate) {
            NavigationStack {
                NewContextGroupSheet { newGroup in
                    groups.append(newGroup)
                    showingCreate = false
                }
            }
            .presentationDetents([.medium, .large])
        }
    }
}

// MARK: - Pinned Row

private struct PinnedContextRow: View {
    let kind: ChatContextKind
    let label: String
    let icon: String
    let typeName: String
    let onUnpin: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.15))
                    .frame(width: 32, height: 32)
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(typeName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            Button {
                onUnpin()
            } label: {
                Image(systemName: "pin.slash")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .padding(8)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Unpin \(label)")
        }
        .padding(.vertical, 2)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                onUnpin()
            } label: {
                Label("Unpin", systemImage: "pin.slash")
            }
        }
    }
}

// MARK: - Row

private struct ContextGroupRow: View {
    let group: ContextGroup

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.15))
                    .frame(width: 36, height: 36)
                Image(systemName: group.icon)
                    .font(.subheadline)
                    .foregroundStyle(Color.accentColor)
            }
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(group.name)
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Text("\(group.members.count)")
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.15), in: Capsule())
                        .foregroundStyle(.secondary)
                }
                if !group.summary.isEmpty {
                    Text(group.summary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                FlowLayout(spacing: 6) {
                    ForEach(group.members) { member in
                        HStack(spacing: 4) {
                            Image(systemName: member.icon)
                                .font(.caption2)
                            Text(member.label)
                                .font(.caption2)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color(.secondarySystemBackground), in: Capsule())
                        .foregroundStyle(.secondary)
                    }
                }
                .padding(.top, 2)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - New Group Sheet (stub)

private struct NewContextGroupSheet: View {
    let onCreate: (ContextGroup) -> Void

    @State private var name: String = ""
    @State private var selectedMembers: Set<ContextGroupMember.ID> = []

    private let candidates: [ContextGroupMember] = ContextGroupMember.library

    var body: some View {
        Form {
            Section("Name") {
                TextField("e.g. Morning Review", text: $name)
            }
            Section("Contexts") {
                ForEach(candidates) { member in
                    Button {
                        if selectedMembers.contains(member.id) {
                            selectedMembers.remove(member.id)
                        } else {
                            selectedMembers.insert(member.id)
                        }
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: member.icon)
                                .frame(width: 22)
                                .foregroundStyle(.blue)
                            Text(member.label)
                                .foregroundStyle(.primary)
                            Spacer()
                            if selectedMembers.contains(member.id) {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(Color.accentColor)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .navigationTitle("New Group")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Create") {
                    let members = candidates.filter { selectedMembers.contains($0.id) }
                    let group = ContextGroup(
                        name: name.isEmpty ? "Untitled Group" : name,
                        icon: "point.3.connected.trianglepath.dotted",
                        summary: "",
                        members: members
                    )
                    onCreate(group)
                }
                .disabled(selectedMembers.isEmpty)
            }
        }
    }
}

// MARK: - Model

struct ContextGroup: Identifiable, Hashable {
    let id: UUID
    var name: String
    var icon: String
    var summary: String
    var members: [ContextGroupMember]

    init(
        id: UUID = UUID(),
        name: String,
        icon: String,
        summary: String,
        members: [ContextGroupMember]
    ) {
        self.id = id
        self.name = name
        self.icon = icon
        self.summary = summary
        self.members = members
    }
}

struct ContextGroupMember: Identifiable, Hashable {
    let id: UUID
    let label: String
    let icon: String
    let contextType: String

    init(id: UUID = UUID(), label: String, icon: String, contextType: String) {
        self.id = id
        self.label = label
        self.icon = icon
        self.contextType = contextType
    }
}

extension ContextGroupMember {
    static let library: [ContextGroupMember] = [
        .init(label: "Today's Schedule", icon: "calendar", contextType: "schedule"),
        .init(label: "Morning Brief", icon: "sunrise", contextType: "brief"),
        .init(label: "Home", icon: "house", contextType: "home"),
        .init(label: "Plans", icon: "list.bullet", contextType: "plans"),
        .init(label: "Health Overview", icon: "heart", contextType: "health"),
        .init(label: "Faith Overview", icon: "cross", contextType: "faith"),
        .init(label: "Profile — Purpose", icon: "target", contextType: "profile"),
        .init(label: "Briefings List", icon: "briefcase", contextType: "briefs")
    ]
}

extension ContextGroup {
    static let mocks: [ContextGroup] = [
        ContextGroup(
            name: "Morning Review",
            icon: "sun.max",
            summary: "What the agent needs to help you plan the day.",
            members: [
                .init(label: "Today's Schedule", icon: "calendar", contextType: "schedule"),
                .init(label: "Morning Brief", icon: "sunrise", contextType: "brief"),
                .init(label: "Home", icon: "house", contextType: "home")
            ]
        ),
        ContextGroup(
            name: "Weekly Planning",
            icon: "calendar.badge.clock",
            summary: "Zoom out across goals, plans, and the week ahead.",
            members: [
                .init(label: "Plans", icon: "list.bullet", contextType: "plans"),
                .init(label: "This Week", icon: "calendar", contextType: "schedule"),
                .init(label: "Profile — Purpose", icon: "target", contextType: "profile"),
                .init(label: "Home", icon: "house", contextType: "home"),
                .init(label: "Briefings List", icon: "briefcase", contextType: "briefs")
            ]
        )
    ]

    static let suggestions: [ContextGroup] = [
        ContextGroup(
            name: "Health Check-in",
            icon: "heart.text.square",
            summary: "Health overview plus today's schedule for a daily reflection.",
            members: [
                .init(label: "Health Overview", icon: "heart", contextType: "health"),
                .init(label: "Today's Schedule", icon: "calendar", contextType: "schedule")
            ]
        ),
        ContextGroup(
            name: "Faith & Purpose",
            icon: "cross.circle",
            summary: "Faith section alongside the goals-purpose profile view.",
            members: [
                .init(label: "Faith Overview", icon: "cross", contextType: "faith"),
                .init(label: "Profile — Purpose", icon: "target", contextType: "profile")
            ]
        )
    ]
}

// MARK: - FlowLayout

private struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: maxWidth == .infinity ? x : maxWidth, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
