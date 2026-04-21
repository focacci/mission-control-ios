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
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Label(call.toolName, systemImage: "wrench.and.screwdriver")
                            .font(.footnote.weight(.medium))
                        Spacer()
                        if call.isError {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.red)
                        }
                        if let ms = call.durationMs {
                            Text("\(ms)ms")
                                .font(.caption2.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    }

                    if !call.input.isEmpty {
                        Text("input:")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(call.input)
                            .font(.caption2.monospaced())
                            .lineLimit(4)
                            .foregroundStyle(.primary)
                    }

                    if let output = call.output, !output.isEmpty {
                        Text("output:")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(output)
                            .font(.caption2.monospaced())
                            .lineLimit(4)
                            .foregroundStyle(.primary)
                    }
                }
                .padding(10)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
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
