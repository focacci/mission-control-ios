import SwiftUI

// MARK: - Context Group Detail
//
// Shows the members of a single `ContextGroup` as a list of context cards.
// Pushed from `ContextGroupsView` when the user taps a group row. Members can
// be removed via swipe; add-to-group happens from any page's context pill.
//
// The view looks up the group from `ChatContextStore.contextGroups` on every
// render (by id) so edits made elsewhere — adds from a context pill, deletes
// from here — stay in sync without passing a binding through.

struct ContextGroupDetailView: View {
    let groupId: ContextGroup.ID

    @Environment(ChatContextStore.self) private var chatContext
    @Environment(\.dismiss) private var dismiss
    @State private var showingEdit = false
    @State private var showingDeleteConfirm = false

    private var groupIndex: Int? {
        chatContext.contextGroups.firstIndex(where: { $0.id == groupId })
    }

    private var group: ContextGroup? {
        groupIndex.map { chatContext.contextGroups[$0] }
    }

    // `nil` while the group hasn't resolved (e.g. just deleted), so we don't
    // overwrite the page context with a half-formed value. `chatContext(_:)`
    // accepts a nullable and simply no-ops in that case.
    private var detailContext: ChatContextKind? {
        guard let group else { return nil }
        return .contextGroupDetails(id: groupId.uuidString, name: group.name)
    }

    var body: some View {
        List {
            if let group {
                if !group.summary.isEmpty {
                    Section {
                        Text(group.summary)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Contexts") {
                    if group.members.isEmpty {
                        Text("This group has no contexts yet. Tap the context pill on any page and choose Add to Context Group.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(group.members) { member in
                            ContextGroupMemberCard(member: member)
                        }
                        .onDelete { indexSet in
                            removeMembers(at: indexSet)
                        }
                    }
                }
            } else {
                Section {
                    Text("This group is no longer available.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .chatContext(detailContext)
        .chatContextToolbar()
        .toolbar {
            if group != nil {
                ToolbarItemGroup(placement: .primaryAction) {
                    Menu {
                        Button {
                            showingEdit = true
                        } label: {
                            Label("Edit", systemImage: "pencil")
                        }
                        Button(role: .destructive) {
                            showingDeleteConfirm = true
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                    }
                }
            }
        }
        .sheet(isPresented: $showingEdit) {
            if let group {
                NavigationStack {
                    EditContextGroupSheet(
                        name: group.name,
                        summary: group.summary
                    ) { newName, newSummary in
                        if let gIdx = groupIndex {
                            chatContext.contextGroups[gIdx].name = newName
                            chatContext.contextGroups[gIdx].summary = newSummary
                        }
                    }
                }
                .presentationDetents([.medium, .large])
            }
        }
        .alert("Delete Context Group?", isPresented: $showingDeleteConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                if let gIdx = groupIndex {
                    chatContext.contextGroups.remove(at: gIdx)
                    dismiss()
                }
            }
        } message: {
            if let group {
                Text("This will permanently delete the group \"\(group.name)\". Its members are unaffected.")
            }
        }
    }

    private func removeMembers(at offsets: IndexSet) {
        guard let gIdx = groupIndex else { return }
        chatContext.contextGroups[gIdx].members.remove(atOffsets: offsets)
    }
}

// MARK: - Edit Sheet

private struct EditContextGroupSheet: View {
    let initialName: String
    let initialSummary: String
    let onSave: (String, String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var summary: String

    init(name: String, summary: String, onSave: @escaping (String, String) -> Void) {
        self.initialName = name
        self.initialSummary = summary
        self.onSave = onSave
        _name = State(initialValue: name)
        _summary = State(initialValue: summary)
    }

    var body: some View {
        Form {
            Section("Name") {
                TextField("Group name", text: $name)
            }
            Section("Summary") {
                TextEditor(text: $summary)
                    .frame(minHeight: 80)
            }
        }
        .navigationTitle("Edit Group")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    onSave(name.trimmingCharacters(in: .whitespaces), summary)
                    dismiss()
                }
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }
}

// MARK: - Member Card

private struct ContextGroupMemberCard: View {
    let member: ContextGroupMember

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.15))
                    .frame(width: 36, height: 36)
                Image(systemName: member.icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(member.label)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(typeDisplayName(member.contextType))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 2)
    }

    // `ContextGroupMember` stores the raw `contextType` string (e.g. "goal")
    // rather than a `ChatContextKind`, so we can't call
    // `ChatContextStore.typeName(for:)` directly. This mirrors the display
    // names from that helper for the types that can land in a group.
    private func typeDisplayName(_ type: String) -> String {
        switch type {
        case "app":            return "App"
        case "home":           return "Home"
        case "agents":         return "Agents"
        case "agent":          return "Agent Details"
        case "agent_chat":     return "Agent Chat"
        case "plans":          return "Plans"
        case "goal":           return "Goal"
        case "initiative":     return "Initiative"
        case "task":              return "Task"
        case "requirement":       return "Requirement"
        case "agent_assignment":  return "Agent Assignment"
        case "schedule":       return "Schedule"
        case "health":         return "Health"
        case "faith":          return "Faith"
        case "briefs":         return "Briefings"
        case "brief":          return "Brief"
        case "feature_list":   return "Features"
        case "context_groups": return "Context Groups"
        case "settings":       return "Settings"
        case "profile":        return "Profile"
        default:               return type.capitalized
        }
    }
}
