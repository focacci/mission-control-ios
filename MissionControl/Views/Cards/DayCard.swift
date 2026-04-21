import SwiftUI

/// Collapsible card representing a single day's schedule. Header shows the
/// weekday/date and a completion summary; tapping toggles the slot list.
/// Used by `WeekScheduleView`; safe to embed anywhere that needs a day summary.
struct DayCard: View {
    let date: Date
    let slots: [ScheduleSlot]
    /// Called when the user taps the header's date chip — lets the caller
    /// navigate to that day's detail view.
    var onTapDate: (() -> Void)? = nil

    @State private var isExpanded: Bool = true

    private var isToday: Bool { date.isoDate == Date().isoDate }

    private var visibleSlots: [ScheduleSlot] {
        slots.filter { $0.type != .maintenance }
    }

    private var doneCount: Int { slots.filter { $0.status == .done }.count }
    private var taskCount: Int { slots.filter { $0.type == .task }.count }

    var body: some View {
        VStack(spacing: 0) {
            header
            if isExpanded {
                if visibleSlots.isEmpty {
                    Text("Nothing scheduled")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 12)
                        .padding(.bottom, 10)
                } else {
                    VStack(spacing: 6) {
                        ForEach(visibleSlots) { slot in
                            NavigationLink(value: slot) {
                                SlotCard(slot: slot)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 10)
                }
            }
        }
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
    }

    @ViewBuilder
    private var header: some View {
        HStack(spacing: 10) {
            Button {
                onTapDate?()
            } label: {
                HStack(spacing: 8) {
                    Text(date.formatted(.dateTime.weekday(.wide)))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(isToday ? Color.accentColor : .primary)

                    Text(date.formatted(.dateTime.month(.abbreviated).day()))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    if isToday {
                        Text("TODAY")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.accentColor, in: Capsule())
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(onTapDate == nil)

            Spacer()

            if taskCount > 0 {
                Text("\(doneCount)/\(taskCount)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Button {
                withAnimation(.easeInOut(duration: 0.18)) { isExpanded.toggle() }
            } label: {
                Image(systemName: "chevron.down")
                    .font(.system(size: 12, weight: .semibold))
                    .rotationEffect(.degrees(isExpanded ? 0 : -90))
                    .foregroundStyle(.secondary)
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}
