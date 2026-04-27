import SwiftUI

/// Compact row used in the Agent Assignment detail's "Agent Outputs" section.
/// Shows status, model, started-at, token total, and a truncated response preview.
struct AgentOutputRow: View {
    let output: AgentOutput

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: output.status.icon)
                    .foregroundStyle(output.status.color)
                Text(output.status.label)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(output.status.color)
                Spacer(minLength: 8)
                Text(relativeStarted)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let preview = previewText, !preview.isEmpty {
                Text(preview)
                    .font(.callout)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
            }

            HStack(spacing: 10) {
                if let model = output.model, !model.isEmpty {
                    Label(model, systemImage: "cpu")
                }
                Label("\(output.tokensIn + output.tokensOut) tok", systemImage: "number")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }

    private var previewText: String? {
        if let r = output.response, !r.isEmpty { return r }
        if let e = output.error, !e.isEmpty { return e }
        return output.input
    }

    private var relativeStarted: String {
        guard let date = ISO8601DateFormatter().date(from: output.startedAt) else {
            return output.startedAt
        }
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f.localizedString(for: date, relativeTo: Date())
    }
}
