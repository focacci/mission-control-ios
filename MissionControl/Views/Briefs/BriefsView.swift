import SwiftUI

// MARK: - Briefings Tab Root

struct BriefsView: View {
    @State private var viewModel = BriefsViewModel()
    @State private var selectedBrief: BriefFullScreenContext?

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(viewModel.days, id: \.self) { day in
                    DayBriefsSection(
                        day: day,
                        viewModel: viewModel,
                        onSelect: { kind, brief in
                            selectedBrief = BriefFullScreenContext(
                                date: day,
                                kind: kind,
                                brief: brief
                            )
                        }
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .chatContext(.briefs)
        .chatContextToolbar()
        .refreshable { await viewModel.load() }
        .errorAlert(message: $viewModel.error)
        .task { await viewModel.load() }
        .navigationDestination(item: $selectedBrief) { ctx in
            BriefFullScreenView(
                kind: ctx.kind,
                date: ctx.date,
                brief: ctx.brief,
                onAcknowledge: { brief in
                    Task { await viewModel.acknowledge(brief: brief) }
                }
            )
        }
    }
}

// MARK: - Full-Screen Brief Presentation

struct BriefFullScreenContext: Identifiable, Hashable {
    let date: Date
    let kind: BriefKind
    let brief: Brief?
    var id: String {
        "\(date.timeIntervalSince1970)-\(kind.rawValue)-\(brief?.id ?? "stub")"
    }
}

struct BriefFullScreenView: View {
    let kind: BriefKind
    let date: Date
    let brief: Brief?
    let onAcknowledge: (Brief) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header

                if let brief, let body = brief.decodedBody {
                    structuredSections(body: body)
                } else if let body = brief?.body, !body.isEmpty {
                    plainTextBody(body)
                } else {
                    fallbackBody
                }

                Spacer(minLength: 40)
            }
            .padding(20)
        }
        .chatContext(.brief(kind: kind.dailyBrief, date: date))
        .chatContextToolbar()
        .onAppear {
            if let brief, brief.status == .ready { onAcknowledge(brief) }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: kind.icon)
                    .font(.title)
                    .foregroundStyle(kind.color)
                Text(brief?.title ?? kind.label)
                    .font(.title2)
                    .fontWeight(.bold)
            }
            Text(date.formatted(.dateTime.weekday(.wide).month().day()))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func structuredSections(body: BriefBody) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionLabel("Summary", icon: "text.alignleft")
            Text(body.summary).font(.body)
        }

        if !body.sections.agentWork.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                sectionLabel("Agent outputs", icon: "cpu")
                ForEach(body.sections.agentWork) { item in
                    BriefBulletRow(
                        text: agentWorkTitle(item),
                        detail: item.oneLineSummary,
                        color: kind.color
                    )
                }
            }
        }

        if !body.sections.openQuestions.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                sectionLabel("Open questions", icon: "questionmark.bubble")
                ForEach(body.sections.openQuestions) { item in
                    BriefBulletRow(text: item.prompt, detail: nil, color: kind.color)
                }
            }
        }

        if !body.sections.userAccomplishments.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                sectionLabel("You did", icon: "checkmark.seal")
                ForEach(body.sections.userAccomplishments) { item in
                    BriefBulletRow(text: item.title, detail: item.detail, color: kind.color)
                }
            }
        }

        if !body.sections.profileGaps.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                sectionLabel("Help me know you", icon: "person.text.rectangle")
                ForEach(body.sections.profileGaps) { item in
                    BriefBulletRow(text: item.prompt, detail: nil, color: kind.color)
                }
            }
        }

        if !body.sections.worldSignal.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                sectionLabel("World", icon: "globe")
                ForEach(body.sections.worldSignal) { item in
                    BriefBulletRow(text: item.headline, detail: item.detail, color: kind.color)
                }
            }
        }
    }

    private func agentWorkTitle(_ item: BriefAgentWorkItem) -> String {
        if let emoji = item.agentEmoji, !emoji.isEmpty {
            return "\(emoji) \(item.title)"
        }
        return item.title
    }

    private func plainTextBody(_ body: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionLabel("Summary", icon: "text.alignleft")
            Text(body).font(.body)
        }
    }

    /// Empty state for stubs, unauthored rows, and pre-reveal drafts. The
    /// client never invents brief content — when there's nothing to show we
    /// say so explicitly so the user can tell whether the agent is still
    /// drafting or simply hasn't started yet.
    private var fallbackBody: some View {
        let availability = BriefAvailability.from(brief: brief)
        return VStack(alignment: .leading, spacing: 12) {
            Image(systemName: emptyIcon(for: availability))
                .font(.title2)
                .foregroundStyle(kind.color.opacity(0.7))
            Text(emptyTitle(for: availability))
                .font(.headline)
            Text(emptyDetail(for: availability))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 8)
    }

    private func emptyIcon(for availability: BriefAvailability) -> String {
        switch availability {
        case .error: return "exclamationmark.triangle"
        case .ready, .acknowledged: return "doc.text"
        default: return "hourglass"
        }
    }

    private func emptyTitle(for availability: BriefAvailability) -> String {
        switch availability {
        case .missing:      return "Not started"
        case .drafting:     return "Drafting"
        case .ready, .acknowledged: return "No content yet"
        case .error:        return "Generation failed"
        }
    }

    private func emptyDetail(for availability: BriefAvailability) -> String {
        switch availability {
        case .missing:
            return "The \(kind.shortLabel.lowercased()) brief hasn't started yet. Briefs are revealed at their scheduled times."
        case .drafting:
            return "The agent is collecting evidence for this brief. It will be revealed at the scheduled time."
        case .ready, .acknowledged:
            return "This brief was finalized without any captured evidence."
        case .error:
            return "Something went wrong finalizing this brief. You can regenerate it from the API."
        }
    }

    private func sectionLabel(_ title: String, icon: String) -> some View {
        Label(title, systemImage: icon)
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundStyle(.secondary)
    }
}

private struct BriefBulletRow: View {
    let text: String
    let detail: String?
    let color: Color

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Circle()
                .fill(color.opacity(0.6))
                .frame(width: 5, height: 5)
                .padding(.top, 7)
            VStack(alignment: .leading, spacing: 2) {
                Text(text).font(.body)
                if let detail, !detail.isEmpty {
                    Text(detail).font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }
}

// MARK: - Day Section

private struct DayBriefsSection: View {
    let day: Date
    let viewModel: BriefsViewModel
    let onSelect: (BriefKind, Brief?) -> Void

    private var dayLabel: String {
        let cal = Calendar.current
        if cal.isDateInToday(day) { return "Today" }
        if cal.isDateInYesterday(day) { return "Yesterday" }
        return day.formatted(.dateTime.weekday(.wide))
    }

    private var dateLabel: String {
        let f = DateFormatter()
        f.dateFormat = "dd MMM, yyyy"
        return f.string(from: day)
    }

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(dayLabel)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text(dateLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            HStack(spacing: 8) {
                ForEach(BriefKind.allCases, id: \.self) { kind in
                    let brief = viewModel.brief(for: kind, date: day)
                    let availability = BriefAvailability.from(brief: brief)
                    BriefIconButton(
                        kind: kind,
                        availability: availability,
                        onTap: { onSelect(kind, brief) }
                    )
                    .contextMenu {
                        OpenChatAboutMenuItem(kind: .brief(kind: kind.dailyBrief, date: day))
                    }
                }
            }
        }
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}

private struct BriefIconButton: View {
    let kind: BriefKind
    let availability: BriefAvailability
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            ZStack(alignment: .topTrailing) {
                Image(systemName: iconName)
                    .font(.title3)
                    .foregroundStyle(iconColor)
                    .frame(width: 40, height: 40)
                    .background(
                        Color.secondary.opacity(availability.isEnabled ? 0.12 : 0.05),
                        in: RoundedRectangle(cornerRadius: 10)
                    )
                    .opacity(availability.isEnabled ? 1.0 : 0.45)

                if availability.hasUnreadBadge {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 8, height: 8)
                        .offset(x: 2, y: -2)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(!availability.isEnabled)
        .accessibilityLabel("\(kind.shortLabel) brief")
    }

    private var iconName: String {
        availability == .error ? "exclamationmark.triangle.fill" : kind.icon
    }

    private var iconColor: Color {
        switch availability {
        case .error:    return .red
        case .missing, .drafting: return .secondary
        default:        return kind.color
        }
    }
}
