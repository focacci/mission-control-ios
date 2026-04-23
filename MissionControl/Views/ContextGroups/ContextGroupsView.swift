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
// Storage lives on `ChatContextStore.contextGroups`. Group members reference
// existing contexts by `(contextType, contextId)` — the same pair persisted
// with chat sessions on the API side.

struct ContextGroupsView: View {
    @Environment(ChatContextStore.self) private var chatContext
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
                if chatContext.contextGroups.isEmpty {
                    Text("No groups yet. Create one, then add contexts to it from any page's context pill.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(chatContext.contextGroups) { group in
                        ContextGroupRow(group: group)
                    }
                    .onDelete { indexSet in
                        chatContext.contextGroups.remove(atOffsets: indexSet)
                    }
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
                NewContextGroupSheet { name in
                    chatContext.createGroup(name: name)
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

// MARK: - New Group Sheet

private struct NewContextGroupSheet: View {
    let onCreate: (String) -> Void

    @State private var name: String = ""

    var body: some View {
        Form {
            Section("Name") {
                TextField("e.g. Morning Review", text: $name)
            }
            Section {
                Text("Add contexts to this group from any page by tapping the context pill and choosing Add to Context Group.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("New Group")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Create") {
                    onCreate(name.trimmingCharacters(in: .whitespaces))
                }
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
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
    let contextId: String?

    init(id: UUID = UUID(), label: String, icon: String, contextType: String, contextId: String? = nil) {
        self.id = id
        self.label = label
        self.icon = icon
        self.contextType = contextType
        self.contextId = contextId
    }

    func matches(_ kind: ChatContextKind) -> Bool {
        contextType == kind.contextType && contextId == kind.contextId
    }
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
