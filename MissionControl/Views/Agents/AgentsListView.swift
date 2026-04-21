import SwiftUI

struct AgentsListView: View {
    @State private var viewModel = AgentsViewModel()
    @State private var showingCreate = false
    @Environment(ChatContextStore.self) private var chatContext

    var body: some View {
        @Bindable var chatContext = chatContext

        NavigationStack {
            Group {
                if viewModel.isLoading && viewModel.agents.isEmpty {
                    ProgressView("Loading agents…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = viewModel.error, viewModel.agents.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundStyle(.orange)
                        Text(error)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.secondary)
                        Button("Retry") {
                            Task { await viewModel.load() }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.agents.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "person.2.badge.gearshape")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                        Text("No agents yet")
                            .font(.headline)
                        Text("Tap + to create your first OpenClaw agent.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(viewModel.agents) { agent in
                        NavigationLink {
                            AgentDetailView(agent: agent) { updated in
                                if let idx = viewModel.agents.firstIndex(where: { $0.id == updated.id }) {
                                    viewModel.agents[idx] = updated
                                }
                            }
                        } label: {
                            AgentRow(agent: agent)
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                        .contextMenu {
                            if !agent.isDefault {
                                Button(role: .destructive) {
                                    Task { await viewModel.deleteAgent(id: agent.id) }
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                    .contentMargins(.bottom, 90, for: .scrollContent)
                    .refreshable { await viewModel.load() }
                    .errorAlert(message: $viewModel.error)
                }
            }
            .floatingChatButton(isPresented: $chatContext.showingChat)
            .navigationTitle("Agents")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { showingCreate = true } label: {
                        Image(systemName: "plus")
                    }
                }
                ToolbarItem(placement: .secondaryAction) {
                    Button {
                        Task { await viewModel.repair() }
                    } label: {
                        Label("Repair agents", systemImage: "wrench.and.screwdriver")
                    }
                }
            }
            .sheet(isPresented: $showingCreate) {
                CreateAgentSheet { name, model, systemPrompt in
                    Task { await viewModel.createAgent(name: name, model: model, systemPrompt: systemPrompt) }
                }
            }
            .task { await viewModel.load() }
            .chatContext(.agents)
        }
    }
}

// MARK: - Agent Row

private struct AgentRow: View {
    let agent: Agent

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(.blue.opacity(0.12))
                    .frame(width: 44, height: 44)
                Text(agent.displayEmoji)
                    .font(.title3)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(agent.displayName)
                        .font(.headline)
                    if agent.isDefault {
                        Text("DEFAULT")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(.blue)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.blue.opacity(0.15), in: Capsule())
                    }
                }

                Text("id: \(agent.id)")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let model = agent.model, !model.isEmpty {
                    Label(model, systemImage: "cpu")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                if let prompt = agent.systemPrompt, !prompt.isEmpty {
                    Text(prompt)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .padding(.top, 2)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
    }
}
