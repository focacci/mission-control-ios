import SwiftUI

struct FeedView: View {
    @State private var viewModel = FeedViewModel()
    @State private var rosaryState = RosaryState()
    @State private var dailyNote = DailyNote()
    @State private var showingNoteEditor = false
    @State private var showingRosary = false
    @State private var expandedBrief: BriefFullScreenContext?
    @State private var showingAllTasks = false

    private var todayISO: String { Date().isoDate }

    private var todaysSlots: [ScheduleSlot] {
        viewModel.todaySlots
            .filter { $0.date == todayISO }
            .sorted { $0.time < $1.time }
    }

    private var remainingCount: Int {
        todaysSlots.filter { $0.status != .done && $0.status != .skipped }.count
    }

    private var nextSlot: ScheduleSlot? {
        if let active = todaysSlots.first(where: { $0.status == .inProgress }) { return active }
        let now = Self.currentHHMM()
        return todaysSlots.first { $0.status != .done && $0.status != .skipped && $0.time >= now }
            ?? todaysSlots.first { $0.status != .done && $0.status != .skipped }
    }

    private var shouldShowNoteNudge: Bool {
        let hour = Calendar.current.component(.hour, from: Date())
        return hour >= 14 && dailyNote.text.isEmpty
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    // Lane A — Agent activity. Each card only renders when
                    // it has data, so an idle agent yields an empty lane and
                    // the brief takes the top of the feed.
                    ForEach(viewModel.runningInvocations) { inv in
                        AgentWorkingCard(
                            invocation: inv,
                            agentName: viewModel.agentName(for: inv.agentId),
                            agentEmoji: viewModel.agentEmoji(for: inv.agentId)
                        )
                    }
                    ForEach(viewModel.errorInvocations) { inv in
                        AgentErrorCard(
                            invocation: inv,
                            agentName: viewModel.agentName(for: inv.agentId),
                            agentEmoji: viewModel.agentEmoji(for: inv.agentId)
                        )
                    }
                    ForEach(viewModel.recentCompleteInvocations) { inv in
                        AgentFinishedCard(
                            invocation: inv,
                            agentName: viewModel.agentName(for: inv.agentId),
                            agentEmoji: viewModel.agentEmoji(for: inv.agentId)
                        )
                    }
                    ForEach(viewModel.queuedAgentSlots) { slot in
                        AgentQueuedCard(slot: slot)
                    }

                    // C1 — One BriefCard per revealed brief. Pre-reveal briefs
                    // are intentionally absent; the Feed never speculates about
                    // a brief that hasn't been finalized.
                    ForEach(viewModel.revealedBriefsToday) { brief in
                        BriefCard(brief: brief, onTap: { openBrief(brief) })
                    }

                    // §7.4 — Missed-brief rollup. A single follow-up card per
                    // unacknowledged brief from the prior 48h, rendered above
                    // the day's other content so the user notices.
                    ForEach(viewModel.missedBriefs) { brief in
                        MissedBriefCard(brief: brief, onTap: { openBrief(brief) })
                    }

                    // D1 — Today's liturgy. Taps into the existing rosary
                    // sheet (no Faith deep-link exists yet).
                    LiturgyCard(
                        mystery: RosaryMystery.forDate(Date()),
                        progress: rosaryState.checkedMysteries.count,
                        onTap: { showingRosary = true }
                    )

                    // E1 — Note nudge, only after 2 PM and only when blank.
                    if shouldShowNoteNudge {
                        NoteNudgeCard(onTap: { showingNoteEditor = true })
                    }

                    NextUpCard(
                        slot: nextSlot,
                        allSlots: todaysSlots,
                        remaining: remainingCount,
                        showingAll: $showingAllTasks,
                        onDone: { slot in Task { await viewModel.doneSlot(slot) } }
                    )

                    // E2 — Status strip pinned at the bottom as the day's
                    // running summary instead of the headline.
                    StatusStrip(
                        rosaryMystery: RosaryMystery.forDate(Date()),
                        rosaryState: rosaryState,
                        dailyNote: dailyNote,
                        onOpenRosary: { showingRosary = true },
                        onOpenNote: { showingNoteEditor = true }
                    )
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .chatContext(.feed)
            .chatContextToolbar()
            .refreshable { await viewModel.load() }
            .errorAlert(message: $viewModel.error)
            .task {
                await viewModel.load()
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(10))
                    await viewModel.refreshLive()
                }
            }
            .sheet(isPresented: $showingNoteEditor) {
                DailyNoteEditorView(note: dailyNote)
            }
            .sheet(isPresented: $showingRosary) {
                RosaryQuickSheet(mystery: RosaryMystery.forDate(Date()), state: rosaryState)
            }
            .navigationDestination(item: $expandedBrief) { ctx in
                BriefFullScreenView(
                    kind: ctx.kind,
                    date: ctx.date,
                    brief: ctx.brief,
                    onAcknowledge: { brief in
                        Task { await viewModel.acknowledge(brief: brief) }
                    }
                )
            }
            .navigationDestination(for: ScheduleSlot.self) { slot in
                if let aa = slot.agentAssignment {
                    AgentAssignmentDetailView(assignment: aa)
                }
            }
            .navigationDestination(for: AgentOutput.self) { output in
                AgentOutputDetailView(output: output)
            }
            .navigationDestination(for: AgentInvocation.self) { inv in
                InvocationDetailView(invocationId: inv.id)
            }
        }
    }

    private func openBrief(_ brief: Brief) {
        guard let date = parseISODate(brief.date) else { return }
        expandedBrief = BriefFullScreenContext(
            date: date,
            kind: brief.kind,
            brief: brief
        )
    }

    private func parseISODate(_ s: String) -> Date? {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(identifier: "America/New_York")
        return f.date(from: s)
    }

    private static func currentHHMM() -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        f.timeZone = TimeZone(identifier: "America/New_York")
        return f.string(from: Date())
    }
}

// MARK: - Brief Feed Cards (Lane C)

/// C1 — Compressed Feed view of a single revealed brief. Shows the reveal
/// label ("Morning Brief · 7:00a"), one-line summary, and a count strip for
/// agent outputs / accomplishments / open questions. Per §7.3 the Feed never
/// renders the full section list — that lives in the Briefs tab.
private struct BriefCard: View {
    let brief: Brief
    let onTap: () -> Void

    private var availability: BriefAvailability { BriefAvailability.from(brief: brief) }

    /// Falls back to a deterministic line when synthesis hasn't produced a
    /// summary yet (e.g. `synthesisFailed = true` on `references`). The Feed
    /// never invents copy — empty states are explicit.
    private var summaryLine: String {
        if let summary = brief.decodedBody?.summary, !summary.isEmpty {
            return summary
        }
        if let title = brief.title, !title.isEmpty {
            return title
        }
        if availability == .error {
            return "Brief generation failed."
        }
        return "No content yet."
    }

    private var revealLabel: String {
        if let revealAt = brief.revealAt, let formatted = BriefCardTimeFormat.timeOfDay(revealAt) {
            return "\(brief.kind.label) · \(formatted)"
        }
        return brief.kind.label
    }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: brief.kind.icon)
                        .font(.subheadline)
                        .foregroundStyle(brief.kind.color)
                    Text(revealLabel)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                    FeedActorChip(actor: .agent)
                    Spacer()
                    if availability.hasUnreadBadge {
                        Circle().fill(Color.red).frame(width: 7, height: 7)
                    }
                }

                Text(summaryLine)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(3)

                if let counts = BriefCardCounts.from(brief: brief) {
                    HStack(spacing: 14) {
                        if counts.agentWork > 0 {
                            BriefCountChip(icon: "cpu", count: counts.agentWork)
                        }
                        if counts.openQuestions > 0 {
                            BriefCountChip(icon: "questionmark.bubble", count: counts.openQuestions)
                        }
                        if counts.accomplishments > 0 {
                            BriefCountChip(icon: "checkmark.seal", count: counts.accomplishments)
                        }
                    }
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                LinearGradient(
                    colors: [brief.kind.color.opacity(0.18), brief.kind.color.opacity(0.04)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ),
                in: RoundedRectangle(cornerRadius: 14)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(brief.kind.color.opacity(0.25), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

/// §7.4 — Missed-brief rollup. Single follow-up card pointing at an
/// unacknowledged brief from the prior 48h. Tap → `BriefFullScreenView`,
/// which acknowledges on appear.
private struct MissedBriefCard: View {
    let brief: Brief
    let onTap: () -> Void

    private var ageLabel: String {
        let cal = Calendar.current
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(identifier: "America/New_York")
        if let date = f.date(from: brief.date) {
            if cal.isDateInYesterday(date) { return "yesterday" }
            return date.formatted(.dateTime.weekday(.wide))
        }
        return brief.date
    }

    private var summaryLine: String {
        if let summary = brief.decodedBody?.summary, !summary.isEmpty {
            return summary
        }
        return "Tap to read the rollup."
    }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "tray.full")
                        .font(.subheadline)
                        .foregroundStyle(brief.kind.color)
                    Text("You missed \(ageLabel)'s \(brief.kind.shortLabel.lowercased()) brief")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                    FeedActorChip(actor: .agent)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                Text(summaryLine)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(brief.kind.color.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct BriefCountChip: View {
    let icon: String
    let count: Int

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text("\(count)")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
        }
    }
}

private struct BriefCardCounts {
    let agentWork: Int
    let openQuestions: Int
    let accomplishments: Int

    static func from(brief: Brief) -> BriefCardCounts? {
        guard let body = brief.decodedBody else { return nil }
        let counts = BriefCardCounts(
            agentWork: body.sections.agentWork.count,
            openQuestions: body.sections.openQuestions.count,
            accomplishments: body.sections.userAccomplishments.count
        )
        if counts.agentWork + counts.openQuestions + counts.accomplishments == 0 {
            return nil
        }
        return counts
    }
}

private enum BriefCardTimeFormat {
    /// Renders the backend's naive `YYYY-MM-DDTHH:MM:00` reveal timestamp as
    /// a human time of day ("7:00a"). Returns nil for malformed input.
    static func timeOfDay(_ revealAt: String) -> String? {
        let parser = DateFormatter()
        parser.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        parser.timeZone = TimeZone(identifier: "America/New_York")
        guard let date = parser.date(from: revealAt) else { return nil }
        let out = DateFormatter()
        out.dateFormat = "h:mma"
        out.timeZone = TimeZone(identifier: "America/New_York")
        out.amSymbol = "a"
        out.pmSymbol = "p"
        return out.string(from: date)
    }
}

// MARK: - Next Up + Full-Day Reveal

private struct NextUpCard: View {
    let slot: ScheduleSlot?
    let allSlots: [ScheduleSlot]
    let remaining: Int
    @Binding var showingAll: Bool
    let onDone: (ScheduleSlot) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Label("Next up", systemImage: "arrow.right.circle")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                Spacer()
                if !allSlots.isEmpty {
                    Text("\(remaining) of \(allSlots.count) left")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.bottom, 10)

            if let slot {
                NextUpRow(slot: slot, onDone: onDone)
            } else {
                HStack(spacing: 10) {
                    Image(systemName: allSlots.isEmpty ? "calendar.badge.exclamationmark" : "checkmark.seal")
                        .foregroundStyle(allSlots.isEmpty ? Color.secondary : Color.green)
                    Text(allSlots.isEmpty ? "Nothing scheduled today" : "Day complete")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.vertical, 6)
            }

            if allSlots.count > 1 {
                Divider().padding(.vertical, 10)
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { showingAll.toggle() }
                } label: {
                    HStack {
                        Text(showingAll ? "Hide full day" : "See all today (\(allSlots.count))")
                            .font(.caption)
                            .fontWeight(.medium)
                        Spacer()
                        Image(systemName: showingAll ? "chevron.up" : "chevron.down")
                            .font(.caption)
                    }
                    .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)

                if showingAll {
                    VStack(spacing: 6) {
                        ForEach(allSlots) { s in
                            NavigationLink(value: s) {
                                SlotCard(slot: s, showBreadcrumb: true)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.top, 10)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
    }
}

private struct NextUpRow: View {
    let slot: ScheduleSlot
    let onDone: (ScheduleSlot) -> Void

    private var breadcrumb: String? {
        guard let desc = slot.agentAssignment?.description, !desc.isEmpty else { return nil }
        return desc
    }

    var body: some View {
        NavigationLink(value: slot) {
            HStack(spacing: 12) {
                VStack(spacing: 2) {
                    Text(slot.time)
                        .font(.system(.footnote, design: .monospaced))
                        .foregroundStyle(.secondary)
                    Image(systemName: slot.typeIcon)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(width: 48)

                VStack(alignment: .leading, spacing: 3) {
                    Text(slot.typeLabel)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                    if let crumb = breadcrumb {
                        Text(crumb)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                if slot.type == .agentAssignment && slot.status != .done {
                    Button {
                        onDone(slot)
                    } label: {
                        Image(systemName: "checkmark.circle")
                            .font(.title2)
                            .foregroundStyle(.green)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Mark done")
                } else {
                    Image(systemName: slot.statusIcon)
                        .foregroundStyle(slot.statusColor)
                        .font(.title3)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Status Strip

private struct StatusStrip: View {
    let rosaryMystery: RosaryMystery
    @Bindable var rosaryState: RosaryState
    @Bindable var dailyNote: DailyNote
    let onOpenRosary: () -> Void
    let onOpenNote: () -> Void

    // Mock targets — will come from Health/nutrition services later.
    private let mealsTotal = 4
    private let mealsLogged = 0
    private let workoutPlanned = true
    private let workoutDone = false

    private var rosaryDone: Bool {
        rosaryState.checkedMysteries.count == 5
    }

    var body: some View {
        HStack(spacing: 8) {
            FeedStatusPill(
                icon: "cross",
                title: "Rosary",
                value: "\(rosaryState.checkedMysteries.count)/5",
                tint: rosaryDone ? .green : .secondary,
                action: onOpenRosary
            )
            FeedStatusPill(
                icon: "fork.knife",
                title: "Meals",
                value: "\(mealsLogged)/\(mealsTotal)",
                tint: mealsLogged >= mealsTotal ? .green : .secondary,
                action: {}
            )
            FeedStatusPill(
                icon: workoutDone ? "figure.strengthtraining.traditional" : "figure.run",
                title: "Workout",
                value: workoutDone ? "Done" : (workoutPlanned ? "Planned" : "—"),
                tint: workoutDone ? .green : .secondary,
                action: {}
            )
            FeedStatusPill(
                icon: dailyNote.text.isEmpty ? "square.and.pencil" : "note.text",
                title: "Note",
                value: dailyNote.text.isEmpty ? "Add" : "Saved",
                tint: dailyNote.text.isEmpty ? .secondary : .blue,
                action: onOpenNote
            )
        }
    }
}

private struct FeedStatusPill: View {
    let icon: String
    let title: String
    let value: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.subheadline)
                    .foregroundStyle(tint)
                Text(value)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Rosary Quick Sheet

private struct RosaryQuickSheet: View {
    let mystery: RosaryMystery
    @Bindable var state: RosaryState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    Text("\(mystery.rawValue) Mysteries")
                        .font(.title3)
                        .fontWeight(.semibold)

                    ForEach(mystery.mysteries, id: \.index) { item in
                        let checked = state.checkedMysteries.contains(item.index)
                        Button {
                            state.toggle(index: item.index)
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: checked ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(checked ? .green : .secondary)
                                Text("\(item.index). \(item.name)")
                                    .font(.body)
                                    .foregroundStyle(checked ? .secondary : .primary)
                                    .strikethrough(checked)
                                Spacer()
                            }
                            .padding(.vertical, 8)
                        }
                        .buttonStyle(.plain)
                        Divider()
                    }
                }
                .padding(20)
            }
            .navigationTitle("Rosary")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

// MARK: - Daily Note Editor

struct DailyNoteEditorView: View {
    let note: DailyNote
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            TextEditor(text: Binding(
                get: { note.text },
                set: { note.text = $0 }
            ))
            .font(.body)
            .padding(12)
            .navigationTitle(note.date)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Feed: Agent Activity Cards (Lane A)

private enum FeedRelativeTime {
    static func string(from iso: String?) -> String {
        guard let iso else { return "" }
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let date = f.date(from: iso) ?? ISO8601DateFormatter().date(from: iso)
        guard let date else { return "" }
        let rel = RelativeDateTimeFormatter()
        rel.unitsStyle = .short
        return rel.localizedString(for: date, relativeTo: Date())
    }
}

private struct FeedActorChip: View {
    enum Actor { case agent, you, world }
    let actor: Actor

    var body: some View {
        Text(label)
            .font(.system(size: 9, weight: .semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.15), in: Capsule())
    }

    private var label: String {
        switch actor {
        case .agent: return "AGENT"
        case .you:   return "YOU"
        case .world: return "WORLD"
        }
    }
    private var color: Color {
        switch actor {
        case .agent: return .purple
        case .you:   return .blue
        case .world: return .secondary
        }
    }
}

/// A2 — Agent working now. Shown for any in-flight autonomous invocation.
private struct AgentWorkingCard: View {
    let invocation: AgentInvocation
    let agentName: String
    let agentEmoji: String

    var body: some View {
        NavigationLink(value: invocation) {
            HStack(alignment: .top, spacing: 12) {
                ProgressView()
                    .controlSize(.small)
                    .padding(.top, 4)

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Text("\(agentEmoji) \(agentName)")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        FeedActorChip(actor: .agent)
                        Spacer()
                    }
                    Text("Working — \(invocation.trigger.displayName.lowercased())")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("Started \(FeedRelativeTime.string(from: invocation.startedAt))")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                LinearGradient(
                    colors: [Color.blue.opacity(0.18), Color.blue.opacity(0.04)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ),
                in: RoundedRectangle(cornerRadius: 14)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(Color.blue.opacity(0.25), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

/// A4 — Agent error. Failed/timed-out runs in the last 24h. Tap → invocation
/// detail so the user can read the error and decide whether to retry.
private struct AgentErrorCard: View {
    let invocation: AgentInvocation
    let agentName: String
    let agentEmoji: String

    private var errorClass: String {
        switch invocation.status {
        case .timeout: return "Timed out"
        case .cancelled: return "Cancelled"
        default:
            if let err = invocation.error?.split(separator: ":").first {
                return String(err)
            }
            return "Failed"
        }
    }

    var body: some View {
        NavigationLink(value: invocation) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                    .font(.title3)

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Text("\(agentEmoji) \(agentName)")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        FeedActorChip(actor: .agent)
                        Spacer()
                        Text(FeedRelativeTime.string(from: invocation.endedAt))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Text(errorClass)
                        .font(.caption)
                        .foregroundStyle(.red)
                    if let err = invocation.error, !err.isEmpty {
                        Text(err)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(Color.red.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

/// A1 — Agent finished. Last few completed autonomous runs.
private struct AgentFinishedCard: View {
    let invocation: AgentInvocation
    let agentName: String
    let agentEmoji: String

    private var totalTokens: Int { invocation.tokensIn + invocation.tokensOut }

    var body: some View {
        NavigationLink(value: invocation) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.title3)

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Text("\(agentEmoji) \(agentName)")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        FeedActorChip(actor: .agent)
                        Spacer()
                        Text(FeedRelativeTime.string(from: invocation.endedAt))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Text("Finished — \(invocation.trigger.displayName.lowercased())")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 10) {
                        Label("\(totalTokens) tokens", systemImage: "circle.hexagongrid")
                        Label(invocation.model, systemImage: "cpu")
                    }
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }
}

/// A3 — Agent queued. Next 1–2 agent-assignment slots that haven't run yet.
private struct AgentQueuedCard: View {
    let slot: ScheduleSlot

    private var title: String {
        slot.agentAssignment?.title ?? "Agent Assignment"
    }

    var body: some View {
        NavigationLink(value: slot) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "clock.badge")
                    .foregroundStyle(.purple)
                    .font(.title3)

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Text("Queued for \(slot.time)")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        FeedActorChip(actor: .agent)
                        Spacer()
                    }
                    Text(title)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(Color.purple.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Feed: World + Human Cards (Lanes D, E)

/// D1 — Today's liturgy. Compact card showing today's Rosary mystery and the
/// user's progress through it. Taps into the existing rosary sheet.
private struct LiturgyCard: View {
    let mystery: RosaryMystery
    let progress: Int
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: "cross.fill")
                    .foregroundStyle(.indigo)
                    .font(.title3)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text("\(mystery.rawValue) Mysteries")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.primary)
                        FeedActorChip(actor: .world)
                    }
                    Text(progress == 5 ? "Complete" : "\(progress) of 5 prayed")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }
}

/// E1 — Note nudge. Surfaces after 2 PM if today's daily note is still empty.
private struct NoteNudgeCard: View {
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: "square.and.pencil")
                    .foregroundStyle(.blue)
                    .font(.title3)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text("Today's note")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.primary)
                        FeedActorChip(actor: .you)
                    }
                    Text("You haven't written one yet — capture a quick reflection.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Briefs (data model + inline detail)

/// Lightweight identifier for the three daily reveal slots. Display copy
/// (`summary`, `highlights`, etc.) lives on the real `Brief` row fetched from
/// the API — there is no client-side mock content.
enum DailyBrief: String, Identifiable, CaseIterable {
    case morning, afternoon, evening

    var id: String { rawValue }
    var label: String {
        switch self {
        case .morning:   return "Morning Brief"
        case .afternoon: return "Afternoon Brief"
        case .evening:   return "Evening Brief"
        }
    }
    var shortLabel: String {
        switch self {
        case .morning:   return "Morning"
        case .afternoon: return "Afternoon"
        case .evening:   return "Evening"
        }
    }
    var icon: String {
        switch self {
        case .morning:   return "sunrise.fill"
        case .afternoon: return "sun.max.fill"
        case .evening:   return "moon.stars.fill"
        }
    }
    var color: Color {
        switch self {
        case .morning:   return .orange
        case .afternoon: return .yellow
        case .evening:   return .indigo
        }
    }
}

