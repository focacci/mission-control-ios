import SwiftUI

/// Debug view over every agent invocation recorded by the API. One row per
/// run — drill in to see transcript and (starting in Phase 2) tool calls.
struct InvocationsListView: View {
    @State private var invocations: [AgentInvocation] = []
    @State private var isLoading = false
    @State private var error: String?
    @State private var triggerFilter: AgentInvocation.Trigger? = nil
    @State private var statusFilter: AgentInvocation.Status? = nil

    var body: some View {
        Group {
            if isLoading && invocations.isEmpty {
                ProgressView("Loading…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if invocations.isEmpty {
                ContentUnavailableView(
                    "No invocations",
                    systemImage: "waveform",
                    description: Text("Agent runs will show up here as they happen.")
                )
            } else {
                List {
                    ForEach(invocations) { inv in
                        NavigationLink {
                            InvocationDetailView(invocationId: inv.id)
                        } label: {
                            InvocationRow(invocation: inv)
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Invocations")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Section("Trigger") {
                        Button("All triggers") { triggerFilter = nil; Task { await load() } }
                        ForEach(AgentInvocation.Trigger.allCases, id: \.self) { t in
                            Button(t.displayName) {
                                triggerFilter = t
                                Task { await load() }
                            }
                        }
                    }
                    Section("Status") {
                        Button("All statuses") { statusFilter = nil; Task { await load() } }
                        ForEach(AgentInvocation.Status.allCases, id: \.self) { s in
                            Button(s.rawValue.capitalized) {
                                statusFilter = s
                                Task { await load() }
                            }
                        }
                    }
                } label: {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                }
            }
        }
        .task { await load() }
        .refreshable { await load() }
        .errorAlert(message: $error)
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            invocations = try await APIClient.shared.invocations(
                trigger: triggerFilter?.rawValue,
                status: statusFilter?.rawValue,
                limit: 100
            )
        } catch {
            self.error = error.localizedDescription
        }
    }
}

// MARK: - Row

private struct InvocationRow: View {
    let invocation: AgentInvocation

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Label(invocation.trigger.displayName, systemImage: invocation.trigger.icon)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)

                Spacer()

                StatusPill(status: invocation.status)
            }

            Text(invocation.agentId)
                .font(.subheadline.weight(.semibold))

            HStack(spacing: 10) {
                Text(invocation.model)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                if invocation.tokensIn + invocation.tokensOut > 0 {
                    Label("\(invocation.tokensIn + invocation.tokensOut)", systemImage: "circle.hexagongrid")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }

            Text(invocation.startedAt)
                .font(.caption2.monospaced())
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }
}

struct StatusPill: View {
    let status: AgentInvocation.Status

    var body: some View {
        Text(status.rawValue.uppercased())
            .font(.system(size: 9, weight: .semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.15), in: Capsule())
    }

    private var color: Color {
        switch status {
        case .running:   return .blue
        case .complete:  return .green
        case .error:     return .red
        case .timeout:   return .orange
        case .cancelled: return .gray
        }
    }
}

// MARK: - Display helpers

extension AgentInvocation.Trigger {
    var displayName: String {
        switch self {
        case .slotStart: return "Slot start"
        case .brief:     return "Brief"
        case .userChat:  return "User chat"
        case .manual:    return "Manual"
        }
    }

    var icon: String {
        switch self {
        case .slotStart: return "calendar.badge.clock"
        case .brief:     return "sun.horizon"
        case .userChat:  return "bubble.left.and.text.bubble.right"
        case .manual:    return "hand.tap"
        }
    }
}
