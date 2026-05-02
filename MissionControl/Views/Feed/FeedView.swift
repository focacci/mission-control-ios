import SwiftUI
import EventKit
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Feed Shell

/// Top-level Feed (Home tab). Composes four explicit sections —
/// header → needs-input → next-up → events — replacing the previous
/// single-list layout. See `Plans/FEED_RESTRUCTURE_PLAN.md` PR 1.
struct FeedView: View {
    @State private var viewModel = FeedViewModel()
    @State private var rosaryState = RosaryState()
    @State private var showingRosary = false
    @State private var showingActiveAgents = false
    @State private var expandedBrief: BriefFullScreenContext?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    HomeHeaderCard(
                        viewModel: viewModel,
                        rosaryState: rosaryState,
                        onOpenRosary: { showingRosary = true },
                        onOpenActiveAgents: { showingActiveAgents = true },
                        onOpenBrief: openBrief
                    )

                    NeedsInputSection(
                        viewModel: viewModel,
                        onOpenBrief: openBrief
                    )

                    NextUpSection(viewModel: viewModel)

                    EventListSection(
                        viewModel: viewModel,
                        onOpenBrief: openBrief
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
            .sheet(isPresented: $showingRosary, onDismiss: {
                viewModel.recomputeStreaks()
            }) {
                RosaryQuickSheet(mystery: RosaryMystery.forDate(Date()), state: rosaryState)
            }
            .sheet(isPresented: $showingActiveAgents) {
                ActiveAgentsSheet(
                    invocations: viewModel.runningInvocations,
                    agentName: viewModel.agentName(for:),
                    agentEmoji: viewModel.agentEmoji(for:)
                )
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
}

// MARK: - Section: Home Header

/// Composed "right now" card. Aggregates the date, today's Rosary,
/// active-agent chip, brief status, and an Up-Next single-line summary.
/// PR 2 fills in the calendar peek; PR 4 adds the streak chip.
private struct HomeHeaderCard: View {
    @Bindable var viewModel: FeedViewModel
    @Bindable var rosaryState: RosaryState
    let onOpenRosary: () -> Void
    let onOpenActiveAgents: () -> Void
    let onOpenBrief: (Brief) -> Void

    private var dateLine: String {
        Date.now.formatted(.dateTime.weekday(.wide).month(.wide).day())
    }

    private var primarySlot: ScheduleSlot? {
        if let inProgress = viewModel.todaySlots.first(where: { $0.status == .inProgress && $0.date == Date().isoDate }) {
            return inProgress
        }
        return viewModel.nextUpSlots.first
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Date row
            HStack {
                Text(dateLine)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Spacer()
                ActiveAgentChip(
                    count: viewModel.runningInvocations.count,
                    hasError: !viewModel.errorInvocations.isEmpty,
                    onTap: onOpenActiveAgents
                )
            }

            Divider().opacity(0.3)

            // Rosary row
            Button(action: onOpenRosary) {
                HStack(spacing: 10) {
                    Image(systemName: "cross.fill")
                        .foregroundStyle(.indigo)
                        .font(.subheadline)
                    let mystery = RosaryMystery.forDate(Date())
                    Text("\(mystery.rawValue) Mysteries")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)
                    if viewModel.streakService.rosary > 0 {
                        RosaryStreakChip(streak: viewModel.streakService.rosary)
                    }
                    Spacer()
                    let progress = rosaryState.checkedMysteries.count
                    Text(progress == 5 ? "Complete" : "\(progress) of 5 prayed")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)

            // Brief status row
            BriefStatusRow(status: viewModel.headerBriefStatus, onOpenBrief: onOpenBrief)

            // Calendar peek (PR 2)
            CalendarPeekRow(
                peek: viewModel.calendarPeek,
                authStatus: viewModel.calendarAuthStatus
            )

            // Up-Next single-line
            if let slot = primarySlot {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.right.circle")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                    Text("Up next")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(slot.time) · \(slot.typeLabel)")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Spacer()
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
    }
}

private struct BriefStatusRow: View {
    let status: HeaderBriefStatus
    let onOpenBrief: (Brief) -> Void

    var body: some View {
        switch status {
        case .none:
            EmptyView()
        case .scheduled(let kind, let revealAt):
            // Pre-reveal briefs are not openable (FEED_PLAN §7.3); render as
            // a non-interactive label.
            HStack(spacing: 8) {
                Image(systemName: kind.icon)
                    .foregroundStyle(kind.color)
                    .font(.caption)
                if let revealAt, let formatted = BriefCardTimeFormat.timeOfDay(revealAt) {
                    Text("\(kind.label) at \(formatted)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text(kind.label)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
        case .drafting(let brief, let runs, let questions, let wins):
            // Live counts pulled from the brief's evolving body. Tap is
            // intentionally disabled — the brief isn't viewable until reveal.
            HStack(spacing: 8) {
                Image(systemName: brief.kind.icon)
                    .foregroundStyle(brief.kind.color)
                    .font(.caption)
                    .symbolEffect(.pulse, options: .repeating)
                Text(draftingLabel(kind: brief.kind, runs: runs, questions: questions, wins: wins))
                    .font(.caption)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                Spacer()
            }
        case .ready(let brief):
            Button { onOpenBrief(brief) } label: {
                HStack(spacing: 8) {
                    Image(systemName: brief.kind.icon)
                        .foregroundStyle(brief.kind.color)
                        .font(.caption)
                    Text("\(brief.kind.label) ready")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)
                    RedDot()
                    Spacer()
                }
            }
            .buttonStyle(.plain)
        case .acknowledged(let brief):
            Button { onOpenBrief(brief) } label: {
                HStack(spacing: 8) {
                    Image(systemName: brief.kind.icon)
                        .foregroundStyle(brief.kind.color.opacity(0.6))
                        .font(.caption)
                    Text("\(brief.kind.label) read")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            }
            .buttonStyle(.plain)
        }
    }

    /// Builds the live-counts string. Suppresses zero-count clauses entirely
    /// so a brief that has only collected agent runs reads "Evening brief ·
    /// 3 runs collected" instead of "… · 3 runs, 0 questions, 0 wins …".
    private func draftingLabel(kind: BriefKind, runs: Int, questions: Int, wins: Int) -> String {
        var parts: [String] = []
        if runs > 0 { parts.append("\(runs) \(runs == 1 ? "run" : "runs")") }
        if questions > 0 { parts.append("\(questions) \(questions == 1 ? "question" : "questions")") }
        if wins > 0 { parts.append("\(wins) \(wins == 1 ? "win" : "wins")") }
        if parts.isEmpty {
            return "\(kind.label) · drafting…"
        }
        return "\(kind.label) · \(parts.joined(separator: ", ")) collected"
    }
}

/// Header row showing the next upcoming calendar event, or a "Connect
/// Calendar" CTA when access is denied / undetermined. Hidden entirely when
/// access is granted but no event is in the 2-day lookahead — the row
/// shouldn't visibly take up space on a quiet day.
private struct CalendarPeekRow: View {
    let peek: EKEvent?
    let authStatus: EKAuthorizationStatus

    var body: some View {
        if let peek {
            HStack(spacing: 8) {
                Image(systemName: "calendar")
                    .foregroundStyle(.secondary)
                    .font(.caption)
                Text(label(for: peek))
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Spacer()
            }
        } else if authStatus == .denied || authStatus == .notDetermined || authStatus == .restricted {
            Button(action: openSettings) {
                HStack(spacing: 8) {
                    Image(systemName: "calendar.badge.plus")
                        .foregroundStyle(.blue)
                        .font(.caption)
                    Text("Connect Calendar")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.blue)
                    Spacer()
                }
            }
            .buttonStyle(.plain)
        } else {
            EmptyView()
        }
    }

    private func label(for event: EKEvent) -> String {
        let title = event.title ?? "Event"
        if event.isAllDay {
            return "All day · \(title)"
        }
        return "\(CalendarTimeFormat.short(event.startDate)) · \(title)"
    }

    private func openSettings() {
        #if canImport(UIKit)
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
        #endif
    }
}

private enum CalendarTimeFormat {
    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "h:mma"
        f.amSymbol = "a"
        f.pmSymbol = "p"
        return f
    }()

    static func short(_ date: Date) -> String { formatter.string(from: date) }
}

// MARK: - Section: Needs Input

/// Surfaces work that requires the user's attention: missed briefs from the
/// prior 48h, open questions raised inside today's revealed briefs, and
/// failed agent runs from the last 24h. Hidden entirely when nothing is
/// outstanding.
private struct NeedsInputSection: View {
    @Bindable var viewModel: FeedViewModel
    let onOpenBrief: (Brief) -> Void

    private var isEmpty: Bool {
        viewModel.missedBriefs.isEmpty &&
        viewModel.openQuestionsToday.isEmpty &&
        viewModel.errorInvocations.isEmpty
    }

    var body: some View {
        if isEmpty {
            EmptyView()
        } else {
            VStack(spacing: 10) {
                HStack {
                    Text("Needs input")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                    Spacer()
                }

                ForEach(viewModel.missedBriefs) { brief in
                    MissedBriefCard(brief: brief, onTap: { onOpenBrief(brief) })
                }

                ForEach(viewModel.openQuestionsToday, id: \.question.id) { pair in
                    OpenQuestionRow(brief: pair.brief, question: pair.question, onTap: { onOpenBrief(pair.brief) })
                }

                ForEach(viewModel.errorInvocations) { inv in
                    AgentErrorRow(
                        invocation: inv,
                        agentName: viewModel.agentName(for: inv.agentId),
                        agentEmoji: viewModel.agentEmoji(for: inv.agentId)
                    )
                }
            }
        }
    }
}

private struct OpenQuestionRow: View {
    let brief: Brief
    let question: BriefQuestionItem
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "questionmark.bubble")
                    .foregroundStyle(.orange)
                    .font(.subheadline)
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(brief.kind.shortLabel + " brief")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                        FeedActorChip(actor: .agent)
                        Spacer()
                        RedDot()
                    }
                    Text(question.prompt)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.leading)
                        .lineLimit(3)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}

private struct AgentErrorRow: View {
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
            HStack(spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                    .font(.subheadline)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text("\(agentEmoji) \(agentName)")
                            .font(.caption)
                            .fontWeight(.semibold)
                        FeedActorChip(actor: .agent)
                        Spacer()
                        RedDot()
                    }
                    Text(errorClass)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Section: Next Up

/// Collapsible list of today's remaining schedule slots. Hidden entirely
/// when nothing is upcoming so the feed stays tight on a quiet day.
private struct NextUpSection: View {
    @Bindable var viewModel: FeedViewModel
    @State private var expanded = false

    var body: some View {
        let slots = viewModel.nextUpSlots
        if slots.isEmpty {
            EmptyView()
        } else {
            VStack(spacing: 0) {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { expanded.toggle() }
                } label: {
                    HStack {
                        Label("Next up · \(slots.count) upcoming", systemImage: "arrow.right.circle")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Image(systemName: expanded ? "chevron.up" : "chevron.down")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal, 14)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.plain)

                if expanded {
                    VStack(spacing: 8) {
                        ForEach(slots) { slot in
                            CompactNextUpRow(slot: slot)
                        }
                    }
                    .padding(.top, 8)
                }
            }
        }
    }
}

private struct CompactNextUpRow: View {
    let slot: ScheduleSlot

    private var breadcrumb: String? {
        guard let desc = slot.agentAssignment?.description, !desc.isEmpty else { return nil }
        return desc
    }

    var body: some View {
        NavigationLink(value: slot) {
            HStack(spacing: 10) {
                VStack(spacing: 2) {
                    Text(slot.time)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                    Image(systemName: slot.typeIcon)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .frame(width: 44)

                VStack(alignment: .leading, spacing: 2) {
                    Text(slot.typeLabel)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                    if let crumb = breadcrumb {
                        Text(crumb)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                Image(systemName: slot.statusIcon)
                    .foregroundStyle(slot.statusColor)
                    .font(.subheadline)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Section: Event List

/// Strict-descending list of past-completed events for today. PR 4 wires
/// the filter chip bar; selection persists across launches via
/// `@AppStorage`.
private struct EventListSection: View {
    @Bindable var viewModel: FeedViewModel
    let onOpenBrief: (Brief) -> Void

    @AppStorage("home.feedFilter") private var rawSelection: String = FeedFilterCategory.all.rawValue

    private var selection: Binding<FeedFilterCategory> {
        Binding(
            get: { FeedFilterCategory(rawValue: rawSelection) ?? .all },
            set: { rawSelection = $0.rawValue }
        )
    }

    var body: some View {
        let allEvents = viewModel.completedEventsToday
        if allEvents.isEmpty {
            EmptyView()
        } else {
            VStack(spacing: 10) {
                EventFilterBar(
                    selection: selection,
                    counts: viewModel.eventCategoryCounts
                )
                let events = viewModel.filteredEvents(selection.wrappedValue)
                if events.isEmpty {
                    Text("No \(selection.wrappedValue.label.lowercased()) events today")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 24)
                } else {
                    VStack(spacing: 12) {
                        ForEach(events) { event in
                            eventCard(event)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func eventCard(_ event: FeedEvent) -> some View {
        switch event {
        case .agentRunning(let inv):
            AgentWorkingCard(
                invocation: inv,
                agentName: viewModel.agentName(for: inv.agentId),
                agentEmoji: viewModel.agentEmoji(for: inv.agentId)
            )
        case .agentError(let inv):
            AgentErrorCard(
                invocation: inv,
                agentName: viewModel.agentName(for: inv.agentId),
                agentEmoji: viewModel.agentEmoji(for: inv.agentId)
            )
        case .agentFinished(let inv):
            AgentFinishedCard(
                invocation: inv,
                agentName: viewModel.agentName(for: inv.agentId),
                agentEmoji: viewModel.agentEmoji(for: inv.agentId)
            )
        case .briefRevealed(let brief):
            BriefCard(brief: brief, onTap: { onOpenBrief(brief) })
        case .calendarEvent(let event):
            CalendarEventCard(event: event)
        }
    }
}

/// Horizontal chip bar above the event list. Selection persists via the
/// caller's `@AppStorage`. Counts are sourced from
/// `FeedViewModel.eventCategoryCounts`; categories with zero events still
/// render so the layout stays stable as data flows in.
private struct EventFilterBar: View {
    @Binding var selection: FeedFilterCategory
    let counts: [FeedFilterCategory: Int]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(FeedFilterCategory.allCases, id: \.self) { cat in
                    Button {
                        selection = cat
                    } label: {
                        HStack(spacing: 6) {
                            Text(cat.label)
                                .font(.caption)
                                .fontWeight(.medium)
                            if let n = counts[cat], n > 0 {
                                Text("\(n)")
                                    .font(.caption2.monospacedDigit())
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .foregroundStyle(selection == cat ? Color.accentColor : .primary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            selection == cat
                                ? Color.accentColor.opacity(0.18)
                                : Color.secondary.opacity(0.08),
                            in: Capsule()
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 2)
        }
    }
}

// MARK: - Active Agents Chip + Sheet

/// Header chip showing the count of currently running autonomous agent
/// invocations. Pulses while any are running. See `Plans/FEED_RESTRUCTURE_PLAN.md`
/// §2.3.
private struct ActiveAgentChip: View {
    let count: Int
    let hasError: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                Image(systemName: "person.wave.2")
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(Color.white, Color.green)
                    .symbolEffect(.pulse.byLayer, options: .repeating, isActive: count > 0)
                Text("\(count)")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .monospacedDigit()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.green.opacity(0.15), in: Capsule())
            .overlay(alignment: .topTrailing) {
                // Red-dot signals at least one errored autonomous run in the
                // last 24h. Even when there are no *active* agents, the user
                // should know something needs attention.
                if hasError {
                    RedDot()
                        .overlay(Circle().stroke(Color(.systemBackground), lineWidth: 1))
                        .offset(x: 3, y: -3)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(count == 0 && !hasError)
        .opacity(count == 0 && !hasError ? 0.5 : 1)
    }
}

/// Daily Rosary streak chip rendered next to the mystery name in the
/// header. Hidden when the streak is zero; the number is the longest run
/// of consecutive completed days ending today (today included once today's
/// mysteries are all checked).
private struct RosaryStreakChip: View {
    let streak: Int

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "flame.fill")
                .foregroundStyle(.orange)
                .font(.caption2)
            Text("\(streak)")
                .font(.caption.monospacedDigit())
                .fontWeight(.semibold)
                .foregroundStyle(.primary)
            Text(streak == 1 ? "day" : "days")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(Color.orange.opacity(0.12), in: Capsule())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Rosary streak: \(streak) \(streak == 1 ? "day" : "days")")
    }
}

/// Sheet listing currently running invocations. Each row routes into
/// `InvocationDetailView`.
// TODO: per-agent chat session view — see Plans/FEED_RESTRUCTURE_PLAN.md §6.
private struct ActiveAgentsSheet: View {
    let invocations: [AgentInvocation]
    let agentName: (String) -> String
    let agentEmoji: (String) -> String

    var body: some View {
        NavigationStack {
            List(invocations) { inv in
                NavigationLink(value: inv) {
                    HStack(spacing: 10) {
                        ProgressView().controlSize(.small)
                        Text("\(agentEmoji(inv.agentId)) \(agentName(inv.agentId))")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Spacer()
                        Text(inv.trigger.displayName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .overlay {
                if invocations.isEmpty {
                    ContentUnavailableView("No active agents", systemImage: "person.wave.2")
                }
            }
            .navigationTitle("Active agents")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: AgentInvocation.self) { inv in
                InvocationDetailView(invocationId: inv.id)
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

// MARK: - Primitives

/// Centralized red-dot indicator. Used wherever a surface needs to signal
/// "needs your attention." Replaces the scattered inline
/// `Circle().fill(.red).frame(width: 7, height: 7)` pattern.
private struct RedDot: View {
    var body: some View {
        Circle().fill(Color.red).frame(width: 7, height: 7)
    }
}

// MARK: - Brief Feed Cards

/// C1 — Compressed Feed view of a single revealed brief. Shows the reveal
/// label ("Morning Brief · 7:00a"), one-line summary, and a count strip for
/// agent outputs / accomplishments / open questions.
private struct BriefCard: View {
    let brief: Brief
    let onTap: () -> Void

    private var availability: BriefAvailability { BriefAvailability.from(brief: brief) }

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
                        RedDot()
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
/// unacknowledged brief from the prior 48h.
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
                    RedDot()
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

/// A4 — Agent error. Failed/timed-out runs in the last 24h.
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

/// Past calendar event surfaced in the EventList. Tagged `YOU` because the
/// user attended/lived through it, distinguishing it from agent activity.
private struct CalendarEventCard: View {
    let event: EKEvent

    private var timeRange: String {
        if event.isAllDay { return "All day" }
        return "\(CalendarTimeFormat.short(event.startDate))–\(CalendarTimeFormat.short(event.endDate))"
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "calendar")
                .foregroundStyle(.blue)
                .font(.title3)

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text(event.title ?? "Event")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                    FeedActorChip(actor: .you)
                    Spacer()
                    Text(FeedRelativeTime.string(from: ISO8601DateFormatter().string(from: event.endDate)))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Text(timeRange)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - Briefs (data model)

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
