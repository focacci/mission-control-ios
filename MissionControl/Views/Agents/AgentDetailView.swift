import SwiftUI

struct AgentDetailView: View {
    let agent: Agent
    var onAgentChanged: ((Agent) -> Void)? = nil
    var onAgentDeleted: ((String) -> Void)? = nil

    @Environment(ChatContextStore.self) private var chatContext
    @Environment(\.dismiss) private var dismiss
    @State private var current: Agent
    @State private var isEditingPrompt = false
    @State private var isSaving = false
    @State private var error: String?
    @State private var selectedSession: ChatSession?
    @State private var showingDeleteConfirm = false

    init(
        agent: Agent,
        onAgentChanged: ((Agent) -> Void)? = nil,
        onAgentDeleted: ((String) -> Void)? = nil
    ) {
        self.agent = agent
        self.onAgentChanged = onAgentChanged
        self.onAgentDeleted = onAgentDeleted
        _current = State(initialValue: agent)
    }

    var body: some View {
        @Bindable var chatContext = chatContext

        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                metadataCard
                systemPromptCard
                newChatButton
                ContextChatHistorySection(agentId: current.id) { session in
                    selectedSession = session
                }
            }
            .padding()
        }
        .chatContext(.agent(
            id: current.id,
            name: current.displayName,
            emoji: current.displayEmoji
        ))
        .chatContextToolbar()
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Menu {
                    Button {
                        isEditingPrompt = true
                    } label: {
                        Label("Edit System Prompt", systemImage: "pencil")
                    }
                    if !current.isDefault {
                        Button(role: .destructive) {
                            showingDeleteConfirm = true
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis")
                }
            }
        }
        .floatingChatButton(isPresented: $chatContext.showingChat)
        .navigationDestination(item: $selectedSession) { session in
            AgentChatView(agent: current, initialSession: session)
        }
        .sheet(isPresented: $isEditingPrompt) {
            EditSystemPromptSheet(
                initialPrompt: current.systemPrompt ?? ""
            ) { newPrompt in
                await saveSystemPrompt(newPrompt)
            }
        }
        .alert("Delete Agent?", isPresented: $showingDeleteConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                Task { await deleteAgent() }
            }
        } message: {
            Text("This will permanently delete \"\(current.displayName)\" and its workspace.")
        }
        .errorAlert(message: $error)
    }

    // MARK: - Sections

    private var header: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(.blue.opacity(0.12))
                    .frame(width: 64, height: 64)
                Text(current.displayEmoji)
                    .font(.system(size: 34))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(current.displayName)
                    .font(.title2.weight(.semibold))
                HStack(spacing: 6) {
                    Text(current.id)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                    if current.isDefault {
                        Text("DEFAULT")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(.blue)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.blue.opacity(0.15), in: Capsule())
                    }
                }
            }
            Spacer()
        }
    }

    private var metadataCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Metadata")
                .font(.headline)

            MetadataRow(icon: "cpu", label: "Model", value: current.model ?? "—")
            MetadataRow(icon: "link", label: "Bindings", value: "\(current.bindings)")
            MetadataRow(icon: "folder", label: "Workspace", value: current.workspace, monospaced: true)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
    }

    private var systemPromptCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("System Prompt")
                    .font(.headline)
                Spacer()
                Button {
                    isEditingPrompt = true
                } label: {
                    Label("Edit", systemImage: "pencil")
                        .labelStyle(.titleAndIcon)
                        .font(.subheadline)
                }
                .disabled(isSaving)
            }

            if let prompt = current.systemPrompt, !prompt.isEmpty {
                Text(prompt)
                    .font(.callout)
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Text("No SOUL.md — add one to shape this agent's personality.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if isSaving {
                ProgressView()
                    .padding(.top, 4)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
    }

    private var newChatButton: some View {
        NavigationLink {
            AgentChatView(agent: current)
        } label: {
            Label("New Chat with \(current.displayName)", systemImage: "square.and.pencil")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(.blue, in: RoundedRectangle(cornerRadius: 14))
                .foregroundStyle(.white)
        }
    }

    // MARK: - Actions

    private func deleteAgent() async {
        isSaving = true
        defer { isSaving = false }
        do {
            try await APIClient.shared.deleteAgent(id: current.id)
            onAgentDeleted?(current.id)
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func saveSystemPrompt(_ newPrompt: String) async {
        isSaving = true
        defer { isSaving = false }

        let trimmed = newPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        let payload: String? = trimmed.isEmpty ? nil : trimmed

        do {
            let updated = try await APIClient.shared.updateAgent(
                id: current.id,
                body: UpdateAgentBody(systemPrompt: payload)
            )
            current = updated
            onAgentChanged?(updated)
        } catch {
            self.error = error.localizedDescription
        }
    }
}

// MARK: - Metadata Row

private struct MetadataRow: View {
    let icon: String
    let label: String
    let value: String
    var monospaced: Bool = false

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Image(systemName: icon)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(width: 18)
            Text(label)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(width: 92, alignment: .leading)
            Text(value)
                .font(monospaced ? .footnote.monospaced() : .footnote)
                .foregroundStyle(.primary)
                .textSelection(.enabled)
                .lineLimit(3)
                .multilineTextAlignment(.leading)
        }
    }
}

// MARK: - Edit System Prompt Sheet

struct EditSystemPromptSheet: View {
    let initialPrompt: String
    let onSave: (String) async -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var text: String
    @State private var isSaving = false

    init(initialPrompt: String, onSave: @escaping (String) async -> Void) {
        self.initialPrompt = initialPrompt
        self.onSave = onSave
        _text = State(initialValue: initialPrompt)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextEditor(text: $text)
                        .frame(minHeight: 240)
                        .font(.callout)
                } header: {
                    Text("SOUL.md")
                } footer: {
                    Text("Leave blank to clear. Written to the agent's workspace as SOUL.md.")
                }
            }
            .navigationTitle("System Prompt")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .disabled(isSaving)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            isSaving = true
                            await onSave(text)
                            isSaving = false
                            dismiss()
                        }
                    }
                    .disabled(isSaving || text == initialPrompt)
                }
            }
        }
        .interactiveDismissDisabled(isSaving)
    }
}
