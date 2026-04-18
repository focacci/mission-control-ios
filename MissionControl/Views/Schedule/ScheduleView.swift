import SwiftUI

struct ScheduleView: View {
    @State private var viewModel = ScheduleViewModel()
    @State private var showingScheduleTask = false
    @State private var slotToAssign: ScheduleSlot?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Week navigation bar + mode picker
                VStack(spacing: 8) {
                    WeekNavBar(
                        weekDates: viewModel.weekDates,
                        focusDate: $viewModel.focusDate,
                        onPrev: { viewModel.stepWeek(by: -1) },
                        onNext: { viewModel.stepWeek(by: 1) }
                    )

                    Picker("View", selection: $viewModel.mode) {
                        ForEach(ScheduleViewMode.allCases, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 16)
                }
                .padding(.bottom, 8)
                .background(Color(.systemBackground))
                .shadow(color: .black.opacity(0.06), radius: 4, y: 2)

                // Content
                Group {
                    if viewModel.isLoading && viewModel.weekResponse == nil {
                        ProgressView("Loading…")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if let error = viewModel.error {
                        ErrorState(message: error) {
                            Task { await viewModel.load() }
                        }
                    } else {
                        switch viewModel.mode {
                        case .day:
                            DayScheduleView(viewModel: viewModel, onAssignToSlot: { slot in
                                slotToAssign = slot
                                showingScheduleTask = true
                            })
                        case .month:
                            MonthScheduleView(viewModel: viewModel)
                        }
                    }
                }
            }
            .navigationTitle("Schedule")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        slotToAssign = nil
                        showingScheduleTask = true
                    } label: {
                        Image(systemName: "plus")
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
            .task { await viewModel.load() }
            .onChange(of: viewModel.weekStart) { _, _ in
                Task { await viewModel.load() }
            }
        }
    }
}

// MARK: - Week Nav Bar (fixed Sun–Sat with arrows)

private struct WeekNavBar: View {
    let weekDates: [Date]
    @Binding var focusDate: Date
    let onPrev: () -> Void
    let onNext: () -> Void

    private let dayLetters = ["S", "M", "T", "W", "T", "F", "S"]
    private let todayISO = Date().isoDate

    var body: some View {
        HStack(spacing: 0) {
            Button(action: onPrev) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(width: 36, height: 44)
                    .contentShape(Rectangle())
            }
            .foregroundStyle(.secondary)

            ForEach(Array(weekDates.enumerated()), id: \.offset) { index, date in
                let iso = date.isoDate
                let isToday = iso == todayISO
                let isSelected = iso == focusDate.isoDate

                VStack(spacing: 3) {
                    Text(dayLetters[index])
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(isToday ? Color.accentColor : .secondary)

                    Text("\(Calendar.current.component(.day, from: date))")
                        .font(.system(size: 13, weight: isSelected ? .bold : .regular))
                        .foregroundStyle(isSelected ? .white : (isToday ? Color.accentColor : .primary))
                        .frame(width: 28, height: 28)
                        .background {
                            if isSelected {
                                Circle().fill(Color.accentColor)
                            } else if isToday {
                                Circle().strokeBorder(Color.accentColor, lineWidth: 1.5)
                            }
                        }
                }
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
                .onTapGesture { focusDate = date }
            }

            Button(action: onNext) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(width: 36, height: 44)
                    .contentShape(Rectangle())
            }
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 4)
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
