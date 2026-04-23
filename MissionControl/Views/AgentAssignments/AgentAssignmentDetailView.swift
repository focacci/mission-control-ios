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
        await patch(body: UpdateAgentAssignmentBody(title: trimmed, instructions: nil, agentId: nil, sortOrder: nil))
    }

    func updateInstructions(_ new: String) async {
        guard new != assignment.instructions else { return }
        await patch(body: UpdateAgentAssignmentBody(title: nil, instructions: new, agentId: nil, sortOrder: nil))
    }

    func setAgent(_ agentId: String?) async {
        guard agentId != assignment.agentId else { return }
        await patch(body: UpdateAgentAssignmentBody(title: nil, instructions: nil, agentId: agentId, sortOrder: nil))
    }

    func toggleComplete() async {
        isSaving = true
        do {
            if assignment.completed {
                // Uncomplete not supported server-side yet; fall back to PATCH.
                assignment = try await APIClient.shared.updateAgentAssignment(
                    id: assignment.id,
                    body: UpdateAgentAssignmentBody(title: nil, instructions: nil, agentId: nil, sortOrder: nil)
                )
            } else {
                assignment = try await APIClient.shared.completeAgentAssignment(id: assignment.id)
            }
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
    @State private var editedInstructions: String
    @FocusState private var field: Field?

    enum Field { case title, instructions }

    let onChange: ((AgentAssignment) -> Void)?

    init(assignment: AgentAssignment, onChange: ((AgentAssignment) -> Void)? = nil) {
        _viewModel = State(initialValue: AgentAssignmentDetailViewModel(assignment: assignment))
        _editedTitle = State(initialValue: assignment.title)
        _editedInstructions = State(initialValue: assignment.instructions)
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
                TextEditor(text: $editedInstructions)
                    .frame(minHeight: 140)
                    .focused($field, equals: .instructions)
            } header: {
                Text("Instructions")
            } footer: {
                Text("What you want the agent to do when this assignment's slot runs.")
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
                HStack(spacing: 10) {
                    Image(systemName: viewModel.assignment.statusIcon)
                        .foregroundStyle(viewModel.assignment.statusColor)
                    Text(viewModel.assignment.statusLabel)
                        .foregroundStyle(.primary)
                    Spacer()
                    if !viewModel.assignment.completed {
                        Button("Mark Complete") {
                            Task {
                                await viewModel.toggleComplete()
                                onChange?(viewModel.assignment)
                            }
                        }
                        .buttonStyle(.bordered)
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
            } else if old == .instructions {
                Task {
                    await viewModel.updateInstructions(editedInstructions)
                    onChange?(viewModel.assignment)
                }
            }
        }
        .errorAlert(message: $viewModel.error)
    }
}
