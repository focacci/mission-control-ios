import SwiftUI

struct ScheduleView: View {
    @State private var viewModel = ScheduleViewModel()
    @State private var showingScheduleTask = false
    @State private var slotToAssign: ScheduleSlot?
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            VStack(spacing: 0) {
                VStack(spacing: 4) {
                    ScheduleBreadcrumb(viewModel: viewModel)
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                    ScheduleNavBar(viewModel: viewModel)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 8)
                }
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
            DayScheduleView(
                viewModel: viewModel,
                onAssignToSlot: { slot in
                    slotToAssign = slot
                    showingScheduleTask = true
                },
                onSelectSlot: { slot in
                    path.append(slot)
                }
            )
        case .week:
            WeekScheduleView(viewModel: viewModel)
        case .month:
            MonthScheduleView(viewModel: viewModel)
        case .year:
            YearScheduleView(viewModel: viewModel)
        }
    }
}

// MARK: - Breadcrumb

/// Scale-switcher breadcrumb: Year › Month › Week › Day. The active scale is
/// emphasized; tapping any crumb jumps directly to that scale without stepping
/// through the intermediate levels.
private struct ScheduleBreadcrumb: View {
    @Bindable var viewModel: ScheduleViewModel

    private let scales: [ScheduleViewMode] = [.year, .month, .week, .day]

    var body: some View {
        HStack(spacing: 6) {
            ForEach(Array(scales.enumerated()), id: \.element) { index, scale in
                Button {
                    guard viewModel.mode != scale else { return }
                    withAnimation(.easeInOut(duration: 0.2)) { viewModel.mode = scale }
                } label: {
                    Text(scale.rawValue)
                        .font(.subheadline.weight(viewModel.mode == scale ? .semibold : .regular))
                        .foregroundStyle(viewModel.mode == scale ? Color.accentColor : Color.secondary)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if index < scales.count - 1 {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Nav bar

/// Period stepper for the current scale. Chevrons step forward/backward; the
/// center label names the *current* period. A "Today" button appears in Day
/// mode when the focus date is outside the current week.
private struct ScheduleNavBar: View {
    @Bindable var viewModel: ScheduleViewModel

    var body: some View {
        HStack(spacing: 8) {
            if viewModel.mode != .day {
                chevron(systemName: "chevron.left") { viewModel.stepPeriod(by: -1) }
            } else {
                Color.clear.frame(width: 32, height: 32)
            }

            Text(labelText)
                .font(.headline)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity)

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
            f.dateFormat = "EEEE, MMM d"
            return f.string(from: d)
        case .week:
            let cal = Calendar.current
            let weekday = cal.component(.weekday, from: d) - 1
            let sunday = cal.date(byAdding: .day, value: -weekday, to: d) ?? d
            f.dateFormat = "MMM d"
            return "Week of \(f.string(from: sunday))"
        case .month:
            f.dateFormat = "MMMM yyyy"
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
