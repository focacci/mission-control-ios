import SwiftUI

struct MonthScheduleView: View {
    @Bindable var viewModel: ScheduleViewModel

    private var calendarDates: [Date?] {
        let cal = Calendar.current
        let components = cal.dateComponents([.year, .month], from: viewModel.focusDate)
        guard let firstOfMonth = cal.date(from: components) else { return [] }
        let firstWeekday = cal.component(.weekday, from: firstOfMonth) - 1 // 0 = Sun
        let daysInMonth = cal.range(of: .day, in: .month, for: firstOfMonth)!.count
        var dates: [Date?] = Array(repeating: nil, count: firstWeekday)
        for day in 1...daysInMonth {
            if let date = cal.date(byAdding: .day, value: day - 1, to: firstOfMonth) {
                dates.append(date)
            }
        }
        // Pad to complete last row
        while dates.count % 7 != 0 { dates.append(nil) }
        return dates
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Month header
                HStack {
                    Button {
                        viewModel.focusDate = Calendar.current.date(
                            byAdding: .month, value: -1, to: viewModel.focusDate) ?? viewModel.focusDate
                    } label: {
                        Image(systemName: "chevron.left")
                    }
                    .foregroundStyle(.secondary)

                    Spacer()

                    Text(viewModel.focusDate.formatted(.dateTime.month(.wide).year()))
                        .font(.headline)

                    Spacer()

                    Button {
                        viewModel.focusDate = Calendar.current.date(
                            byAdding: .month, value: 1, to: viewModel.focusDate) ?? viewModel.focusDate
                    } label: {
                        Image(systemName: "chevron.right")
                    }
                    .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)

                // Day-of-week header
                HStack(spacing: 0) {
                    ForEach(["S","M","T","W","T","F","S"], id: \.self) { letter in
                        Text(letter)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal, 8)

                Divider().padding(.top, 4)

                // Calendar grid
                let rows = calendarDates.chunked(into: 7)
                ForEach(Array(rows.enumerated()), id: \.offset) { _, week in
                    HStack(spacing: 0) {
                        ForEach(Array(week.enumerated()), id: \.offset) { _, date in
                            MonthDayCell(
                                date: date,
                                isSelected: date.map { $0.isoDate == viewModel.focusDateISO } ?? false,
                                isToday: date.map { $0.isoDate == Date().isoDate } ?? false,
                                hasTasks: date.map { viewModel.datesWithSlots.contains($0.isoDate) } ?? false
                            )
                            .onTapGesture {
                                if let date { viewModel.focusDate = date }
                            }
                        }
                    }
                    Divider()
                }

                // Day detail for selected date
                let selectedSlots = viewModel.slotsForFocusDate.filter { $0.type != "maintenance" }
                if !selectedSlots.isEmpty {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(viewModel.focusDate.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 16)
                            .padding(.top, 16)
                            .padding(.bottom, 8)

                        ForEach(selectedSlots) { slot in
                            NavigationLink(value: slot) {
                                SlotCard(slot: slot)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 4)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
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

// MARK: - Array chunked helper

private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}
