import SwiftUI
import Observation

@Observable
final class AgentOutputsListViewModel {
    var outputs: [AgentOutput] = []
    var isLoading = false
    var error: String?

    func load() async {
        isLoading = true
        do {
            outputs = try await APIClient.shared.allAgentOutputs()
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }
}

/// Aggregate list of every Agent Output across all assignments. Pushed from
/// the More tab's "Agent" section.
struct AgentOutputsListView: View {
    @State private var viewModel = AgentOutputsListViewModel()

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.outputs.isEmpty {
                ProgressView("Loading…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.outputs.isEmpty {
                ContentUnavailableView(
                    "No Agent Outputs",
                    systemImage: "text.page",
                    description: Text("Agent outputs will appear here as your agent assignments run.")
                )
            } else {
                List {
                    ForEach(viewModel.outputs) { output in
                        NavigationLink(value: output) {
                            AgentOutputRow(output: output)
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("Agent Outputs")
        .navigationBarTitleDisplayMode(.inline)
        .chatContext(.agentOutputs)
        .chatContextToolbar()
        .task { await viewModel.load() }
        .refreshable { await viewModel.load() }
        .errorAlert(message: $viewModel.error)
        .navigationDestination(for: AgentOutput.self) { output in
            AgentOutputDetailView(output: output)
        }
    }
}
