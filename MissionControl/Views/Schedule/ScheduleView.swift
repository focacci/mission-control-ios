import SwiftUI

struct ScheduleView: View {
    @State private var viewModel = ScheduleViewModel()
    @State private var showingScheduleTask = false
    @State private var slotToAssign: ScheduleSlot?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScheduleNavBar(viewModel: viewModel)
                    .padding(.horizontal, 16)
                    .padding(.top, 4)
                    .padding(.bottom, 8)
                    .background(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.06), radius: 4, y: 2)

                Group {
                    if viewModel.isLoading && viewModel.slotsByDate.isEmpty {
                        ProgressView("Loading…")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if let error = viewModel.error {
                        ErrorState(message: error) {
                            Task { await viewModel.load() }
                        }
                    } else {
                        content
                    }
                }
            }
            .chatContextToolbar()
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Today") {
                        viewModel.mode = .day
                        viewModel.focusDate = Date()
                    }
                }
            }
            .navigationDestination(for: ScheduleSlot.self) { slot in
                if let taskId = slot.taskId {
                    TaskDetailView(taskId: taskId)
                } else {
                    SlotDetailView(slot: slot, viewModel: viewModel)
                }
            }
            .sheet(isPresented: $showingScheduleTask, onDismiss: { slotToAssign = nil }) {
                ScheduleTaskSheet(
                    targetDate: slotToAssign.flatMap { ISO8601DateFormatter.shared.date(from: $0.date) }
                        ?? viewModel.focusDate,
                    preselectedSlot: slotToAssign
                ) {
                    Task { await viewModel.load() }
                }
            }
            .task(id: viewModel.loadKey) { await viewModel.load() }
            .chatContext(.schedule(date: viewModel.focusDate, mode: viewModel.mode))
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.mode {
        case .day:
            DayScheduleView(viewModel: viewModel, onAssignToSlot: { slot in
                slotToAssign = slot
                showingScheduleTask = true
            })
        case .week:
            WeekScheduleView(viewModel: viewModel)
        case .month:
            MonthScheduleView(viewModel: viewModel)
        case .year:
            YearScheduleView(viewModel: viewModel)
        }
    }
}

// MARK: - Nav bar

/// Hierarchical navigation header. The center label names the *parent* period
/// (e.g. in Day mode it says "Week of Mar 2") and tapping it zooms out one
/// level. Chevrons step the current mode's period forward/backward; a "Today"
/// button appears when the focus date is outside the current period.
private struct ScheduleNavBar: View {
    @Bindable var viewModel: ScheduleViewModel

    var body: some View {
        HStack(spacing: 8) {
            if viewModel.mode != .day {
                chevron(systemName: "chevron.left") { viewModel.stepPeriod(by: -1) }
            } else {
                Color.clear.frame(width: 32, height: 32)
            }

            Button {
                if viewModel.mode.zoomedOut != nil {
                    withAnimation(.easeInOut(duration: 0.2)) { viewModel.zoomOut() }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(labelText)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    if viewModel.mode.zoomedOut != nil {
                        Image(systemName: "chevron.up")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.secondary)
                    }
                }
                .contentShape(Rectangle())
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)
            .disabled(viewModel.mode.zoomedOut == nil)

            if viewModel.mode != .day {
                chevron(systemName: "chevron.right") { viewModel.stepPeriod(by: 1) }
            } else if !viewModel.isFocusInCurrentPeriod {
                Button {
                    viewModel.focusDate = Date()
                } label: {
                    Text("Today")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Color.accentColor)
                        .frame(height: 32)
                        .padding(.horizontal, 8)
                }
                .buttonStyle(.plain)
            } else {
                Color.clear.frame(width: 32, height: 32)
            }
        }
    }

    private var labelText: String {
        let f = DateFormatter()
        let d = viewModel.focusDate
        switch viewModel.mode {
        case .day:
            let cal = Calendar.current
            let weekday = cal.component(.weekday, from: d) - 1
            let sunday = cal.date(byAdding: .day, value: -weekday, to: d) ?? d
            f.dateFormat = "MMM d"
            return "Week of \(f.string(from: sunday))"
        case .week:
            f.dateFormat = "MMMM yyyy"
            return f.string(from: d)
        case .month:
            f.dateFormat = "yyyy"
            return f.string(from: d)
        case .year:
            f.dateFormat = "yyyy"
            return f.string(from: d)
        }
    }

    @ViewBuilder
    private func chevron(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 32, height: 32)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

extension ScheduleViewModel {
    /// True when the focus date is in the *current* period for the active mode.
    var isFocusInCurrentPeriod: Bool {
        let cal = Calendar.current
        let now = Date()
        switch mode {
        case .day:
            // Week-level: are both in the same week?
            return cal.isDate(focusDate, equalTo: now, toGranularity: .weekOfYear)
        case .week:
            return cal.isDate(focusDate, equalTo: now, toGranularity: .weekOfYear)
        case .month:
            return cal.isDate(focusDate, equalTo: now, toGranularity: .month)
        case .year:
            return cal.isDate(focusDate, equalTo: now, toGranularity: .year)
        }
    }
}

// MARK: - Error State

private struct ErrorState: View {
    let message: String
    let retry: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundStyle(.orange)
            Text(message)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Button("Retry", action: retry)
                .buttonStyle(.borderedProminent)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
