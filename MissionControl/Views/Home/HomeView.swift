import SwiftUI

struct HomeView: View {
    @State private var viewModel = HomeViewModel()
    @State private var rosaryState = RosaryState()
    @State private var dailyNote = DailyNote()
    @State private var showingNoteEditor = false
    @State private var showingRosary = false
    @State private var selectedBrief: DailyBrief?
    @State private var expandedBrief: BriefFullScreenContext?
    @State private var pendingExpandBrief: DailyBrief?
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

    private var currentBrief: DailyBrief {
        switch Calendar.current.component(.hour, from: Date()) {
        case ..<11:   return .morning
        case 11..<17: return .afternoon
        default:      return .evening
        }
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

                    // C1 — Brief, demoted from headline to one card among many.
                    BriefHeroCard(
                        brief: currentBrief,
                        otherBriefs: DailyBrief.allCases.filter { $0 != currentBrief },
                        onTapPrimary: { selectedBrief = currentBrief },
                        onTapOther: { selectedBrief = $0 }
                    )

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
            .chatContext(.home)
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
            .sheet(item: $selectedBrief, onDismiss: {
                if let brief = pendingExpandBrief {
                    pendingExpandBrief = nil
                    expandedBrief = BriefFullScreenContext(date: Date(), brief: brief)
                }
            }) { brief in
                BriefDetailView(brief: brief, onExpand: {
                    pendingExpandBrief = brief
                    selectedBrief = nil
                })
            }
            .navigationDestination(item: $expandedBrief) { ctx in
                BriefFullScreenView(brief: ctx.brief, date: ctx.date)
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

    private static func currentHHMM() -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        f.timeZone = TimeZone(identifier: "America/New_York")
        return f.string(from: Date())
    }
}

// MARK: - Brief Hero

private struct BriefHeroCard: View {
    let brief: DailyBrief
    let otherBriefs: [DailyBrief]
    let onTapPrimary: () -> Void
    let onTapOther: (DailyBrief) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: brief.icon)
                    .font(.title2)
                    .foregroundStyle(brief.color)
                VStack(alignment: .leading, spacing: 1) {
                    Text(brief.label)
                        .font(.headline)
                    Text(Date().formatted(.dateTime.weekday(.wide).month().day()))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                HStack(spacing: 6) {
                    ForEach(otherBriefs) { other in
                        Button { onTapOther(other) } label: {
                            Image(systemName: other.icon)
                                .font(.footnote)
                                .foregroundStyle(other.color)
                                .frame(width: 28, height: 28)
                                .background(Color.secondary.opacity(0.12), in: Circle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(other.shortLabel) brief")
                    }
                }
            }

            Button(action: onTapPrimary) {
                VStack(alignment: .leading, spacing: 10) {
                    Text(brief.summary)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.leading)
                        .lineLimit(4)

                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(brief.highlights.prefix(2), id: \.self) { item in
                            HStack(alignment: .top, spacing: 8) {
                                Circle()
                                    .fill(brief.color.opacity(0.7))
                                    .frame(width: 4, height: 4)
                                    .padding(.top, 7)
                                Text(item)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.leading)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [brief.color.opacity(0.18), brief.color.opacity(0.04)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 16)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(brief.color.opacity(0.25), lineWidth: 1)
        )
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
            HomeStatusPill(
                icon: "cross",
                title: "Rosary",
                value: "\(rosaryState.checkedMysteries.count)/5",
                tint: rosaryDone ? .green : .secondary,
                action: onOpenRosary
            )
            HomeStatusPill(
                icon: "fork.knife",
                title: "Meals",
                value: "\(mealsLogged)/\(mealsTotal)",
                tint: mealsLogged >= mealsTotal ? .green : .secondary,
                action: {}
            )
            HomeStatusPill(
                icon: workoutDone ? "figure.strengthtraining.traditional" : "figure.run",
                title: "Workout",
                value: workoutDone ? "Done" : (workoutPlanned ? "Planned" : "—"),
                tint: workoutDone ? .green : .secondary,
                action: {}
            )
            HomeStatusPill(
                icon: dailyNote.text.isEmpty ? "square.and.pencil" : "note.text",
                title: "Note",
                value: dailyNote.text.isEmpty ? "Add" : "Saved",
                tint: dailyNote.text.isEmpty ? .secondary : .blue,
                action: onOpenNote
            )
        }
    }
}

private struct HomeStatusPill: View {
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
    var summary: String {
        switch self {
        case .morning:
            return "Good morning. You have 4 tasks scheduled, a 50-minute upper-body workout, and two games tonight. Weather is 62° and clear — good day for the zone 2 walk after lunch."
        case .afternoon:
            return "Halfway through the day. You've logged 2 of 4 meals and taken 3 of 5 supplements. Two tasks remaining before the 5pm deep-work block. Hydration is on track at 48 oz."
        case .evening:
            return "Day wrapping up. You completed 3 of 4 tasks, hit your workout, and logged all meals. One task rolled forward to tomorrow. Wind-down suggestion: finish by 10:15 for 7.5+ hours of sleep."
        }
    }
    var highlights: [String] {
        switch self {
        case .morning:
            return [
                "4 tasks scheduled, 2 deep-work blocks",
                "Upper Body Strength — 50 min (planned)",
                "Celtics vs. Knicks at 7:30 PM",
                "Rosary: Glorious Mysteries",
            ]
        case .afternoon:
            return [
                "Tasks: 2 done, 2 remaining",
                "Meals logged: Breakfast, Lunch",
                "Hydration: 6 of 8 cups",
                "Deep-work block begins at 5:00 PM",
            ]
        case .evening:
            return [
                "Completed 3 of 4 tasks today",
                "Workout: done (52 min logged)",
                "Notes captured: 1 daily note",
                "Tomorrow: lower body strength + 3 meetings",
            ]
        }
    }
}

struct BriefDetailView: View {
    let brief: DailyBrief
    let onExpand: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 10) {
                            Image(systemName: brief.icon)
                                .font(.title)
                                .foregroundStyle(brief.color)
                            Text(brief.label)
                                .font(.title2)
                                .fontWeight(.bold)
                        }
                        Text(Date().formatted(.dateTime.weekday(.wide).month().day()))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Label("Summary", systemImage: "text.alignleft")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                        Text(brief.summary)
                            .font(.body)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Label("Highlights", systemImage: "sparkles")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)

                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(brief.highlights, id: \.self) { item in
                                HStack(alignment: .top, spacing: 8) {
                                    Circle()
                                        .fill(brief.color.opacity(0.6))
                                        .frame(width: 5, height: 5)
                                        .padding(.top, 7)
                                    Text(item)
                                        .font(.body)
                                }
                            }
                        }
                    }

                    Spacer(minLength: 40)
                }
                .padding(20)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: onExpand) {
                        Image(systemName: "arrow.down.left.and.arrow.up.right")
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}
