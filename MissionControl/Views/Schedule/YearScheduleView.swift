import SwiftUI

/// Year overview — 4×3 grid of month tiles. Tapping a tile zooms to Month
/// view for that month. Each tile highlights the current month and shows a
/// subtle dot when any task slot falls inside it.
struct YearScheduleView: View {
    @Bindable var viewModel: ScheduleViewModel

    private var year: Int {
        Calendar.current.component(.year, from: viewModel.focusDate)
    }

    private var currentMonth: Int {
        Calendar.current.component(.month, from: Date())
    }

    private var currentYear: Int {
        Calendar.current.component(.year, from: Date())
    }

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 3)

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(1...12, id: \.self) { month in
                    MonthTile(
                        year: year,
                        month: month,
                        isCurrentMonth: month == currentMonth && year == currentYear,
                        hasTasks: viewModel.monthHasSlots(year: year, month: month)
                    )
                    .onTapGesture {
                        if let date = Calendar.current.date(from: DateComponents(year: year, month: month, day: 1)) {
                            viewModel.zoomIn(to: .month, date: date)
                        }
                    }
                }
            }
            .padding(16)
        }
    }
}

private struct MonthTile: View {
    let year: Int
    let month: Int
    let isCurrentMonth: Bool
    let hasTasks: Bool

    private var monthName: String {
        let f = DateFormatter()
        f.dateFormat = "MMM"
        return f.monthSymbols[month - 1]
    }

    var body: some View {
        VStack(spacing: 6) {
            Text(monthName)
                .font(.headline)
                .foregroundStyle(isCurrentMonth ? Color.accentColor : .primary)

            Circle()
                .fill(hasTasks ? Color.accentColor : Color.clear)
                .frame(width: 5, height: 5)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 22)
        .background {
            RoundedRectangle(cornerRadius: 14)
                .fill(.regularMaterial)
            if isCurrentMonth {
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(Color.accentColor.opacity(0.6), lineWidth: 1.5)
            }
        }
        .contentShape(RoundedRectangle(cornerRadius: 14))
    }
}
