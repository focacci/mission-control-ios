import SwiftUI
import Observation

@Observable
final class AgentOutputDetailViewModel {
    var output: AgentOutput
    var steps: [AgentOutputStep] = []
    var isLoading = false
    var error: String?

    init(output: AgentOutput) {
        self.output = output
    }

    func load() async {
        isLoading = true
        do {
            let detail = try await APIClient.shared.agentOutput(id: output.id)
            output = detail.output
            steps = detail.steps
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }
}

/// Push-navigation detail for one Agent Output. Renders a vertical timeline:
/// header → input → ordered steps → final response.
struct AgentOutputDetailView: View {
    @State var viewModel: AgentOutputDetailViewModel

    init(output: AgentOutput) {
        _viewModel = State(initialValue: AgentOutputDetailViewModel(output: output))
    }

    private var context: ChatContextKind {
        let title = "Run \(viewModel.output.startedAt.prefix(10))"
        return .agentOutput(id: viewModel.output.id, title: String(title))
    }

    var body: some View {
        List {
            headerSection
            inputSection
            runSection
            responseSection
        }
        .navigationTitle("Agent Output")
        .navigationBarTitleDisplayMode(.inline)
        .chatContext(context)
        .chatContextToolbar()
        .task { await viewModel.load() }
        .refreshable { await viewModel.load() }
        .errorAlert(message: $viewModel.error)
    }

    // MARK: - Sections

    private var headerSection: some View {
        Section {
            HStack(spacing: 10) {
                Image(systemName: viewModel.output.status.icon)
                    .foregroundStyle(viewModel.output.status.color)
                Text(viewModel.output.status.label)
                    .font(.headline)
                    .foregroundStyle(viewModel.output.status.color)
                Spacer()
            }
            if let model = viewModel.output.model, !model.isEmpty {
                LabeledContent("Model", value: model)
            }
            LabeledContent("Started", value: viewModel.output.startedAt)
            if let ended = viewModel.output.endedAt {
                LabeledContent("Ended", value: ended)
                if let duration = durationString(from: viewModel.output.startedAt, to: ended) {
                    LabeledContent("Duration", value: duration)
                }
            }
            LabeledContent("Tokens", value: "in \(viewModel.output.tokensIn) · out \(viewModel.output.tokensOut)")
            if let err = viewModel.output.error {
                Text(err)
                    .font(.callout)
                    .foregroundStyle(.red)
            }
        }
    }

    private var inputSection: some View {
        Section("Input") {
            Text(viewModel.output.input)
                .font(.callout)
                .textSelection(.enabled)
        }
    }

    @ViewBuilder
    private var runSection: some View {
        if !viewModel.steps.isEmpty {
            Section("Run") {
                ForEach(viewModel.steps) { step in
                    AgentOutputStepView(step: step)
                }
            }
        } else if viewModel.output.status == .running {
            Section("Run") {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("Waiting for steps…")
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    @ViewBuilder
    private var responseSection: some View {
        Section("Response") {
            if let response = viewModel.output.response, !response.isEmpty {
                Text(response)
                    .font(.callout)
                    .textSelection(.enabled)
            } else if viewModel.output.status == .running {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("Run in progress…")
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("No response.")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func durationString(from start: String, to end: String) -> String? {
        let f = ISO8601DateFormatter()
        guard let s = f.date(from: start), let e = f.date(from: end) else { return nil }
        let interval = e.timeIntervalSince(s)
        if interval < 60 { return String(format: "%.1fs", interval) }
        let mins = Int(interval) / 60
        let secs = Int(interval) % 60
        return "\(mins)m \(secs)s"
    }
}

/// Renders a single timeline step. `tool_call` and `thinking` are collapsible.
private struct AgentOutputStepView: View {
    let step: AgentOutputStep
    @State private var expanded = false

    var body: some View {
        switch step.kind {
        case .thinking:
            DisclosureGroup(isExpanded: $expanded) {
                Text(step.content ?? "")
                    .font(.footnote)
                    .italic()
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            } label: {
                Label("Thinking", systemImage: "lightbulb")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        case .toolCall:
            toolCallView
        case .text:
            Text(step.content ?? "")
                .font(.callout)
                .textSelection(.enabled)
        }
    }

    private var toolCallView: some View {
        VStack(alignment: .leading, spacing: 6) {
            DisclosureGroup(isExpanded: $expanded) {
                VStack(alignment: .leading, spacing: 8) {
                    if let input = step.toolInput, !input.isEmpty {
                        Text("Input")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text(prettyJSON(input))
                            .font(.system(.footnote, design: .monospaced))
                            .textSelection(.enabled)
                    }
                    if let output = step.toolOutput, !output.isEmpty {
                        Text("Output")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text(output)
                            .font(.system(.footnote, design: .monospaced))
                            .foregroundStyle(step.isError ? .red : .primary)
                            .textSelection(.enabled)
                    }
                }
                .padding(.top, 4)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: step.isError ? "wrench.adjustable.fill" : "wrench.adjustable")
                        .foregroundStyle(step.isError ? .red : .accentColor)
                    Text(step.toolName ?? "tool")
                        .font(.subheadline.weight(.medium))
                    Spacer()
                    if let ms = step.durationMs {
                        Text("\(ms)ms")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .stroke(step.isError ? Color.red.opacity(0.4) : Color.secondary.opacity(0.2))
        )
    }

    private func prettyJSON(_ raw: String) -> String {
        guard let data = raw.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data),
              let pretty = try? JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted, .sortedKeys]),
              let str = String(data: pretty, encoding: .utf8) else {
            return raw
        }
        return str
    }
}
