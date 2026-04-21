import SwiftUI

struct WeekScheduleView: View {
    @Bindable var viewModel: ScheduleViewModel

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(viewModel.slotsByDay, id: \.date) { entry in
                    DayCard(
                        date: entry.date,
                        slots: entry.slots,
                        onTapDate: {
                            viewModel.zoomIn(to: .day, date: entry.date)
                        }
                    )
                    .padding(.horizontal, 16)
                }
            }
            .padding(.top, 12)
            .padding(.bottom, 90)
        }
    }
}
