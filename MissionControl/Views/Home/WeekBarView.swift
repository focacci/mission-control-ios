import SwiftUI

struct WeekBarView: View {
    let weekDates: [Date]
    let selectedDate: Date
    var onSelect: ((Date) -> Void)?

    private let dayLetters = ["S", "M", "T", "W", "T", "F", "S"]
    private let todayISO = Date().isoDate

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(weekDates.enumerated()), id: \.offset) { index, date in
                let iso = date.isoDate
                let isToday = iso == todayISO
                let isSelected = iso == selectedDate.isoDate

                VStack(spacing: 4) {
                    Text(dayLetters[index])
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(isToday ? Color.accentColor : .secondary)

                    Text("\(Calendar.current.component(.day, from: date))")
                        .font(.system(size: 14, weight: isSelected ? .bold : .regular))
                        .foregroundStyle(isSelected ? .white : (isToday ? Color.accentColor : .primary))
                        .frame(width: 30, height: 30)
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
                .onTapGesture { onSelect?(date) }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(.systemBackground))
        .shadow(color: .black.opacity(0.06), radius: 4, y: 2)
    }
}
