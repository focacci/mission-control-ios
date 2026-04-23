import SwiftUI

/// Full detail for one `AgentInvocation`: metadata, token counts, transcript,
/// and (Phase 2+) tool calls.
struct InvocationDetailView: View {
    let invocationId: String

    @State private var detail: InvocationDetail?
    @State private var isLoading = true
    @State private var error: String?

    var body: some View {
        Group {
            if let detail {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        metadata(detail.invocation)
                        if !detail.toolCalls.isEmpty {
                            toolCalls(detail.toolCalls)
                        }
                        transcript(detail.messages)
                    }
                    .padding()
                }
            } else if isLoading {
                ProgressView("Loading…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error {
                ContentUnavailableView {
                    Label("Error", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(error)
                } actions: {
                    Button("Retry") { Task { await load() } }
                        .buttonStyle(.borderedProminent)
                }
            }
        }
        .navigationTitle("Invocation")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .refreshable { await load() }
    }

    // MARK: - Sections

    private func metadata(_ inv: AgentInvocation) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(inv.trigger.displayName, systemImage: inv.trigger.icon)
                    .font(.subheadline.weight(.medium))
                Spacer()
                StatusPill(status: inv.status)
            }

            Divider()

            MetaRow(label: "Agent",    value: inv.agentId, mono: true)
            MetaRow(label: "Model",    value: inv.model, mono: true)
            MetaRow(label: "Session",  value: inv.sessionId, mono: true)
            if let ref = inv.triggerRefId {
                MetaRow(label: "Ref", value: ref, mono: true)
            }
            MetaRow(label: "Started",  value: inv.startedAt, mono: true)
            if let ended = inv.endedAt {
                MetaRow(label: "Ended", value: ended, mono: true)
            }
            MetaRow(label: "Tokens",   value: "in \(inv.tokensIn) / out \(inv.tokensOut)", mono: true)
            if let runId = inv.gatewayRunId {
                MetaRow(label: "Run ID", value: runId, mono: true)
            }

            if let err = inv.error {
                Divider()
                Text(err)
                    .font(.caption.monospaced())
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
    }

    private func transcript(_ msgs: [ChatTranscriptMessage]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Transcript")
                .font(.headline)

            if msgs.isEmpty {
                Text("No messages.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(msgs) { msg in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(msg.role.rawValue.uppercased())
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(msg.role == .user ? .blue : .secondary)
                        Text(msg.content)
                            .font(.footnote)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(10)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
                }
            }
        }
    }

    private func toolCalls(_ calls: [ToolCallLog]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Tool Calls (\(calls.count))")
                .font(.headline)

            ForEach(calls) { call in
                ToolCallRow(call: call)
            }
        }
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            detail = try await APIClient.shared.invocation(id: invocationId)
        } catch {
            self.error = error.localizedDescription
        }
    }
}

/// Collapsed row for one tool call. Shows the server-provided `summary` when
/// available (Phase 2+); expand-on-tap reveals raw input/output JSON for
/// debugging. Older invocations without a summary render just the raw
/// payloads.
private struct ToolCallRow: View {
    let call: ToolCallLog
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button {
                withAnimation(.easeInOut(duration: 0.15)) { isExpanded.toggle() }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: call.isError ? "exclamationmark.triangle.fill" : "wrench.and.screwdriver")
                        .font(.caption)
                        .foregroundStyle(call.isError ? .red : .secondary)
                    Text(call.toolName)
                        .font(.footnote.weight(.medium))
                    if let summary = call.summary, !summary.isEmpty {
                        Text("·")
                            .foregroundStyle(.tertiary)
                        Text(summary)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                    if let ms = call.durationMs {
                        Text("\(ms)ms")
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(.tertiary)
                    }
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                if !call.input.isEmpty {
                    Text("input")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(call.input)
                        .font(.caption2.monospaced())
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                if let output = call.output, !output.isEmpty {
                    Text("output")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(output)
                        .font(.caption2.monospaced())
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding(10)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
    }
}

private struct MetaRow: View {
    let label: String
    let value: String
    var mono: Bool = false

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(label)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(width: 68, alignment: .leading)
            Text(value)
                .font(mono ? .footnote.monospaced() : .footnote)
                .foregroundStyle(.primary)
                .textSelection(.enabled)
                .lineLimit(3)
                .multilineTextAlignment(.leading)
        }
    }
}
