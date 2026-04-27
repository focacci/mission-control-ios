import SwiftUI
import Observation

@Observable
final class AgentAssignmentDetailViewModel {
    var assignment: AgentAssignment
    var agents: [Agent] = []
    var isSaving = false
    var error: String?

    init(assignment: AgentAssignment) {
        self.assignment = assignment
    }

    func loadAgents() async {
        do {
            agents = try await APIClient.shared.agents()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func refresh() async {
        do {
            assignment = try await APIClient.shared.agentAssignment(id: assignment.id)
        } catch {
            self.error = error.localizedDescription
        }
    }

    func updateTitle(_ new: String) async {
        let trimmed = new.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != assignment.title else { return }
        await patch(body: UpdateAgentAssignmentBody(title: trimmed, description: nil, agentId: nil, sortOrder: nil))
    }

    func updateDescription(_ new: String) async {
        let normalized = new.isEmpty ? nil : new
        guard normalized != assignment.description else { return }
        await patch(body: UpdateAgentAssignmentBody(title: nil, description: normalized, agentId: nil, sortOrder: nil))
    }

    func setAgent(_ agentId: String?) async {
        guard agentId != assignment.agentId else { return }
        await patch(body: UpdateAgentAssignmentBody(title: nil, description: nil, agentId: agentId, sortOrder: nil))
    }

    func start() async {
        await runStatusChange { try await APIClient.shared.startAgentAssignment(id: $0) }
    }

    func complete() async {
        await runStatusChange { try await APIClient.shared.completeAgentAssignment(id: $0) }
    }

    func block() async {
        await runStatusChange { try await APIClient.shared.blockAgentAssignment(id: $0) }
    }

    func reopen() async {
        await runStatusChange { try await APIClient.shared.reopenAgentAssignment(id: $0) }
    }

    func unassign() async {
        await runStatusChange { try await APIClient.shared.unassignAgentAssignment(id: $0) }
    }

    private func runStatusChange(_ op: (String) async throws -> AgentAssignment) async {
        isSaving = true
        do {
            assignment = try await op(assignment.id)
        } catch {
            self.error = error.localizedDescription
        }
        isSaving = false
    }

    private func patch(body: UpdateAgentAssignmentBody) async {
        isSaving = true
        do {
            assignment = try await APIClient.shared.updateAgentAssignment(id: assignment.id, body: body)
        } catch {
            self.error = error.localizedDescription
        }
        isSaving = false
    }
}

struct AgentAssignmentDetailView: View {
    @State var viewModel: AgentAssignmentDetailViewModel
    @State private var editedTitle: String
    @State private var editedDescription: String
    @FocusState private var field: Field?

    enum Field { case title, description }

    let onChange: ((AgentAssignment) -> Void)?

    init(assignment: AgentAssignment, onChange: ((AgentAssignment) -> Void)? = nil) {
        _viewModel = State(initialValue: AgentAssignmentDetailViewModel(assignment: assignment))
        _editedTitle = State(initialValue: assignment.title)
        _editedDescription = State(initialValue: assignment.description ?? "")
        self.onChange = onChange
    }

    private var context: ChatContextKind {
        .agentAssignment(id: viewModel.assignment.id, title: viewModel.assignment.title)
    }

    var body: some View {
        List {
            Section("Title") {
                TextField("Title", text: $editedTitle)
                    .focused($field, equals: .title)
                    .onSubmit {
                        Task {
                            await viewModel.updateTitle(editedTitle)
                            onChange?(viewModel.assignment)
                        }
                    }
            }

            Section {
                TextEditor(text: $editedDescription)
                    .frame(minHeight: 140)
                    .focused($field, equals: .description)
            } header: {
                Text("Description")
            } footer: {
                Text("Optional context for the agent when this assignment's slot runs.")
            }

            Section("Agent") {
                Picker("Agent", selection: Binding(
                    get: { viewModel.assignment.agentId ?? "__default__" },
                    set: { new in
                        let id = new == "__default__" ? nil : new
                        Task {
                            await viewModel.setAgent(id)
                            onChange?(viewModel.assignment)
                        }
                    }
                )) {
                    Text("Default").tag("__default__")
                    ForEach(viewModel.agents) { agent in
                        Text(agent.name).tag(agent.id)
                    }
                }
            }

            Section("Status") {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 10) {
                        AgentAssignmentStatusIcon(assignment: viewModel.assignment)
                        Text(viewModel.assignment.statusLabel)
                            .foregroundStyle(.primary)
                        Spacer()
                    }

                    HStack(spacing: 8) {
                        if viewModel.assignment.canStart {
                            Button("Start") {
                                Task {
                                    await viewModel.start()
                                    onChange?(viewModel.assignment)
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(viewModel.isSaving)
                        }
                        if viewModel.assignment.canComplete {
                            Button("Complete") {
                                Task {
                                    await viewModel.complete()
                                    onChange?(viewModel.assignment)
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.green)
                            .disabled(viewModel.isSaving)
                        }
                        if viewModel.assignment.canBlock {
                            Button("Block") {
                                Task {
                                    await viewModel.block()
                                    onChange?(viewModel.assignment)
                                }
                            }
                            .buttonStyle(.bordered)
                            .tint(.red)
                            .disabled(viewModel.isSaving)
                        }
                        if viewModel.assignment.canReopen {
                            Button("Reopen") {
                                Task {
                                    await viewModel.reopen()
                                    onChange?(viewModel.assignment)
                                }
                            }
                            .buttonStyle(.bordered)
                            .disabled(viewModel.isSaving)
                        }
                        Button("Unassign") {
                            Task {
                                await viewModel.unassign()
                                onChange?(viewModel.assignment)
                            }
                        }
                        .buttonStyle(.bordered)
                        .tint(.gray)
                        .disabled(viewModel.isSaving)
                    }
                }
            }

            if let slots = viewModel.assignment.slots, !slots.isEmpty {
                Section("Scheduled Slots") {
                    ForEach(slots) { slot in
                        HStack(spacing: 10) {
                            Image(systemName: "calendar.badge.clock")
                                .foregroundStyle(.secondary)
                            Text("\(slot.dayOfWeek) • \(slot.date) • \(slot.time)")
                                .font(.subheadline)
                            Spacer()
                        }
                    }
                }
            }

            ContextChatHistorySection(
                contextType: "agent_assignment",
                contextId: viewModel.assignment.id
            )
        }
        .navigationTitle("Agent Assignment")
        .navigationBarTitleDisplayMode(.inline)
        .chatContext(context)
        .chatContextToolbar()
        .task { await viewModel.loadAgents() }
        .refreshable { await viewModel.refresh() }
        .onChange(of: field) { old, _ in
            if old == .title {
                Task {
                    await viewModel.updateTitle(editedTitle)
                    onChange?(viewModel.assignment)
                }
            } else if old == .description {
                Task {
                    await viewModel.updateDescription(editedDescription)
                    onChange?(viewModel.assignment)
                }
            }
        }
        .errorAlert(message: $viewModel.error)
    }
}
