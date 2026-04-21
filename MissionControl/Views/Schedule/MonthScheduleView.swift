import SwiftUI

struct MonthScheduleView: View {
    @Bindable var viewModel: ScheduleViewModel

    /// Calendar grid for the focused month, padded to whole weeks (Sun..Sat).
    private var weeks: [[Date?]] {
        let cal = Calendar.current
        let components = cal.dateComponents([.year, .month], from: viewModel.focusDate)
        guard let firstOfMonth = cal.date(from: components) else { return [] }
        let firstWeekday = cal.component(.weekday, from: firstOfMonth) - 1
        let daysInMonth = cal.range(of: .day, in: .month, for: firstOfMonth)!.count
        var dates: [Date?] = Array(repeating: nil, count: firstWeekday)
        for day in 1...daysInMonth {
            if let date = cal.date(byAdding: .day, value: day - 1, to: firstOfMonth) {
                dates.append(date)
            }
        }
        while dates.count % 7 != 0 { dates.append(nil) }
        return stride(from: 0, to: dates.count, by: 7).map { Array(dates[$0..<$0 + 7]) }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Day-of-week header — aligned with the grid below.
                HStack(spacing: 0) {
                    // Spacer for the week-button gutter on the left.
                    Color.clear.frame(width: 22)
                    ForEach(["S","M","T","W","T","F","S"], id: \.self) { letter in
                        Text(letter)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.top, 8)

                Divider().padding(.top, 4)

                // Calendar grid
                ForEach(Array(weeks.enumerated()), id: \.offset) { _, week in
                    HStack(spacing: 0) {
                        weekButton(for: week)

                        ForEach(Array(week.enumerated()), id: \.offset) { _, date in
                            MonthDayCell(
                                date: date,
                                isSelected: date.map { $0.isoDate == viewModel.focusDateISO } ?? false,
                                isToday: date.map { $0.isoDate == Date().isoDate } ?? false,
                                hasTasks: date.map { viewModel.datesWithSlots.contains($0.isoDate) } ?? false
                            )
                            .onTapGesture {
                                if let date {
                                    viewModel.zoomIn(to: .day, date: date)
                                }
                            }
                        }
                    }
                    Divider()
                }
            }
        }
    }

    /// Chevron button on the left gutter of each week row; tapping opens that
    /// week in Week view (using the row's first non-nil date, which is the
    /// Sunday of that week).
    @ViewBuilder
    private func weekButton(for week: [Date?]) -> some View {
        let anchor = week.compactMap { $0 }.first
        Button {
            if let anchor {
                viewModel.zoomIn(to: .week, date: anchor)
            }
        } label: {
            Image(systemName: "chevron.right")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 22, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(anchor == nil)
    }
}

// MARK: - Month Day Cell

private struct MonthDayCell: View {
    let date: Date?
    let isSelected: Bool
    let isToday: Bool
    let hasTasks: Bool

    var body: some View {
        VStack(spacing: 4) {
            if let date {
                Text("\(Calendar.current.component(.day, from: date))")
                    .font(.system(size: 14, weight: isSelected ? .bold : .regular))
                    .foregroundStyle(isSelected ? .white : (isToday ? Color.accentColor : .primary))
                    .frame(width: 28, height: 28)
                    .background {
                        if isSelected {
                            Circle().fill(Color.accentColor)
                        } else if isToday {
                            Circle().strokeBorder(Color.accentColor, lineWidth: 1.5)
                        }
                    }

                Circle()
                    .fill(hasTasks ? Color.accentColor : Color.clear)
                    .frame(width: 4, height: 4)
            } else {
                Color.clear.frame(width: 28, height: 28)
                Color.clear.frame(width: 4, height: 4)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .contentShape(Rectangle())
    }
}
