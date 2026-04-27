import SwiftUI

/// Detail page for a single agent-calendar time slot. Shows the assigned task
/// (if any), the contexts / context groups the agent should consult when this
/// slot fires, and an optional per-slot prompt addendum. All of the
/// context-attachment state is local to the view for now — backend
/// persistence will follow once the control-layer slot schema lands.
struct TimeSlotView: View {
    let slot: ScheduleSlot
    let viewModel: ScheduleViewModel
    let onAssignTap: () -> Void

    @Environment(ChatContextStore.self) private var chatContext

    @State private var linkedContexts: [ChatContextKind] = []
    @State private var linkedGroupIds: Set<UUID> = []
    @State private var extraPrompt: String = ""

    @State private var showingContextPicker = false
    @State private var showingGroupPicker = false

    private var slotDate: Date {
        ISO8601DateFormatter.shared.date(from: slot.date) ?? viewModel.focusDate
    }

    private var dayLabel: String {
        let f = DateFormatter()
        f.dateFormat = "EEE, MMM d"
        return f.string(from: slotDate)
    }

    private var linkedGroups: [ContextGroup] {
        chatContext.contextGroups.filter { linkedGroupIds.contains($0.id) }
    }

    var body: some View {
        List {
            slotInfoSection
            taskSection
            linkedContextsSection
            linkedGroupsSection
            extraPromptSection

            if slot.status == .pending || slot.status == .inProgress {
                actionsSection
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .chatContext(.timeSlot(slotId: slot.id, time: slot.time, dayLabel: dayLabel))
        .chatContextToolbar()
        .navigationDestination(for: AgentAssignment.self) { aa in
            AgentAssignmentDetailView(assignment: aa)
        }
        .navigationDestination(for: AgentOutput.self) { output in
            AgentOutputDetailView(output: output)
        }
        .sheet(isPresented: $showingContextPicker) {
            ContextSourcePicker(
                pinned: chatContext.pinnedContexts,
                alreadyLinked: linkedContexts,
                store: chatContext,
                onPick: { kind in
                    if !linkedContexts.contains(kind) {
                        linkedContexts.append(kind)
                    }
                    showingContextPicker = false
                }
            )
        }
        .sheet(isPresented: $showingGroupPicker) {
            GroupSourcePicker(
                groups: chatContext.contextGroups,
                alreadyLinked: linkedGroupIds,
                onPick: { id in
                    linkedGroupIds.insert(id)
                    showingGroupPicker = false
                }
            )
        }
    }

    // MARK: - Sections

    private var slotInfoSection: some View {
        Section("Slot Info") {
            LabeledContent("Time", value: "\(slot.dayOfWeek) \(slot.time)")
            LabeledContent("Type", value: slot.typeLabel)
            LabeledContent("Status") {
                HStack(spacing: 6) {
                    Image(systemName: slot.statusIcon)
                        .foregroundStyle(slot.statusColor)
                    Text(slot.status.displayName)
                        .foregroundStyle(slot.statusColor)
                }
            }
            if let note = slot.note {
                LabeledContent("Note", value: note)
            }
        }
    }

    @ViewBuilder
    private var taskSection: some View {
        Section("Assigned Agent Assignment") {
            if let aa = slot.agentAssignment {
                NavigationLink(value: aa) {
                    HStack(spacing: 10) {
                        AgentAssignmentStatusIcon(assignment: aa)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(aa.title)
                                .font(.body)
                            if let desc = aa.description, !desc.isEmpty {
                                Text(desc)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                        }
                    }
                }
                Button(role: .destructive) {
                    Task { await viewModel.unassignAgentAssignment(slot: slot) }
                } label: {
                    Label("Unassign", systemImage: "minus.circle")
                }
            } else {
                Button(action: onAssignTap) {
                    Label("Assign Agent Assignment", systemImage: "plus.circle")
                }
            }
        }
    }

    private var linkedContextsSection: some View {
        Section {
            if linkedContexts.isEmpty {
                Text("No linked contexts yet.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(linkedContexts.enumerated()), id: \.offset) { _, kind in
                    HStack(spacing: 10) {
                        Image(systemName: chatContext.icon(for: kind))
                            .foregroundStyle(.secondary)
                            .frame(width: 20)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(chatContext.label(for: kind))
                                .font(.body)
                            Text(chatContext.typeName(for: kind))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .onDelete { idx in
                    linkedContexts.remove(atOffsets: idx)
                }
            }
            Button {
                showingContextPicker = true
            } label: {
                Label("Link a Context", systemImage: "plus.circle")
            }
        } header: {
            Text("Linked Contexts")
        } footer: {
            Text("The agent will load these when this slot runs.")
        }
    }

    private var linkedGroupsSection: some View {
        Section {
            if linkedGroups.isEmpty {
                Text("No linked context groups.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(linkedGroups) { group in
                    HStack(spacing: 10) {
                        Image(systemName: group.icon)
                            .foregroundStyle(.secondary)
                            .frame(width: 20)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(group.name)
                                .font(.body)
                            Text("\(group.members.count) member\(group.members.count == 1 ? "" : "s")")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            linkedGroupIds.remove(group.id)
                        } label: {
                            Label("Unlink", systemImage: "minus.circle")
                        }
                    }
                }
            }
            Button {
                showingGroupPicker = true
            } label: {
                Label("Link a Group", systemImage: "plus.circle")
            }
            .disabled(chatContext.contextGroups.isEmpty)
        } header: {
            Text("Linked Context Groups")
        }
    }

    private var extraPromptSection: some View {
        Section {
            TextEditor(text: $extraPrompt)
                .frame(minHeight: 120)
                .font(.callout)
        } header: {
            Text("Extra Prompt")
        } footer: {
            Text("Appended to the agent's system prompt for this slot only.")
        }
    }

    private var actionsSection: some View {
        Section("Actions") {
            Button {
                Task { await viewModel.markDone(slot: slot) }
            } label: {
                Label("Mark Done", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }
            Button {
                Task { await viewModel.markSkip(slot: slot) }
            } label: {
                Label("Skip Slot", systemImage: "forward.circle.fill")
                    .foregroundStyle(.orange)
            }
        }
    }
}

// MARK: - Pickers

private struct ContextSourcePicker: View {
    let pinned: [ChatContextKind]
    let alreadyLinked: [ChatContextKind]
    let store: ChatContextStore
    let onPick: (ChatContextKind) -> Void

    @Environment(\.dismiss) private var dismiss

    private var available: [ChatContextKind] {
        pinned.filter { !alreadyLinked.contains($0) }
    }

    var body: some View {
        NavigationStack {
            List {
                if available.isEmpty {
                    Section {
                        Text("Pin a context from any page's toolbar to see it here.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Section("Pinned Contexts") {
                        ForEach(Array(available.enumerated()), id: \.offset) { _, kind in
                            Button {
                                onPick(kind)
                            } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: store.icon(for: kind))
                                        .foregroundStyle(.secondary)
                                        .frame(width: 20)
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(store.label(for: kind))
                                            .foregroundStyle(.primary)
                                        Text(store.typeName(for: kind))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Link a Context")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

private struct GroupSourcePicker: View {
    let groups: [ContextGroup]
    let alreadyLinked: Set<UUID>
    let onPick: (UUID) -> Void

    @Environment(\.dismiss) private var dismiss

    private var available: [ContextGroup] {
        groups.filter { !alreadyLinked.contains($0.id) }
    }

    var body: some View {
        NavigationStack {
            List {
                if available.isEmpty {
                    Section {
                        Text("Create a context group from the Groups page to link it here.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    ForEach(available) { group in
                        Button {
                            onPick(group.id)
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: group.icon)
                                    .foregroundStyle(.secondary)
                                    .frame(width: 20)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(group.name)
                                        .foregroundStyle(.primary)
                                    Text("\(group.members.count) member\(group.members.count == 1 ? "" : "s")")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                            }
                        }
                    }
                }
            }
            .navigationTitle("Link a Group")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
