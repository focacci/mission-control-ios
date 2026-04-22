import SwiftUI

// MARK: - Briefs Tab Root

struct BriefsView: View {
    @State private var expandedDays: Set<Date>
    @State private var selectedBrief: BriefFullScreenContext?

    private let days: [Date]

    init() {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        self.days = (0..<14).compactMap { cal.date(byAdding: .day, value: -$0, to: today) }
        self._expandedDays = State(initialValue: [today])
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(days, id: \.self) { day in
                        DayBriefsSection(
                            day: day,
                            isExpanded: expandedDays.contains(day),
                            onToggle: { toggle(day) },
                            onSelect: { brief in
                                selectedBrief = BriefFullScreenContext(date: day, brief: brief)
                            }
                        )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .chatContext(.briefs)
            .chatContextToolbar()
            .navigationDestination(item: $selectedBrief) { ctx in
                BriefFullScreenView(brief: ctx.brief, date: ctx.date)
            }
        }
    }

    private func toggle(_ day: Date) {
        withAnimation(.easeInOut(duration: 0.2)) {
            if expandedDays.contains(day) {
                expandedDays.remove(day)
            } else {
                expandedDays.insert(day)
            }
        }
    }
}

// MARK: - Full-Screen Brief Presentation

struct BriefFullScreenContext: Identifiable, Hashable {
    let date: Date
    let brief: DailyBrief
    var id: String { "\(date.timeIntervalSince1970)-\(brief.rawValue)" }
}

struct BriefFullScreenView: View {
    let brief: DailyBrief
    let date: Date

    var body: some View {
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
                    Text(date.formatted(.dateTime.weekday(.wide).month().day()))
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
        .chatContext(.brief(kind: brief, date: date))
        .chatContextToolbar()
    }
}

// MARK: - Day Section

private struct DayBriefsSection: View {
    let day: Date
    let isExpanded: Bool
    let onToggle: () -> Void
    let onSelect: (DailyBrief) -> Void

    private var dayLabel: String {
        let cal = Calendar.current
        if cal.isDateInToday(day) { return "Today" }
        if cal.isDateInYesterday(day) { return "Yesterday" }
        return day.formatted(.dateTime.weekday(.wide))
    }

    private var dateLabel: String {
        day.formatted(.dateTime.month(.abbreviated).day().year())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: onToggle) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(dayLabel)
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Text(dateLabel)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .contentShape(Rectangle())
                .padding(14)
            }
            .buttonStyle(.plain)

            if isExpanded {
                Divider()
                HStack(spacing: 8) {
                    ForEach(DailyBrief.allCases) { brief in
                        Button {
                            onSelect(brief)
                        } label: {
                            VStack(spacing: 6) {
                                Image(systemName: brief.icon)
                                    .font(.title3)
                                    .foregroundStyle(brief.color)
                                Text(brief.shortLabel)
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundStyle(.primary)
                                Text("Brief")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(14)
            }
        }
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}
