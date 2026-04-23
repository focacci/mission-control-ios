import SwiftUI

// MARK: - Briefings Tab Root

struct BriefsView: View {
    @State private var selectedBrief: BriefFullScreenContext?

    private let days: [Date]

    init() {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        self.days = (0..<14).compactMap { cal.date(byAdding: .day, value: -$0, to: today) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(days, id: \.self) { day in
                        DayBriefsSection(
                            day: day,
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
    let onSelect: (DailyBrief) -> Void

    private var dayLabel: String {
        let cal = Calendar.current
        if cal.isDateInToday(day) { return "Today" }
        if cal.isDateInYesterday(day) { return "Yesterday" }
        return day.formatted(.dateTime.weekday(.wide))
    }

    private var dateLabel: String {
        let f = DateFormatter()
        f.dateFormat = "dd MMM, yyyy"
        return f.string(from: day)
    }

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(dayLabel)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text(dateLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            HStack(spacing: 8) {
                ForEach(DailyBrief.allCases) { brief in
                    Button {
                        onSelect(brief)
                    } label: {
                        Image(systemName: brief.icon)
                            .font(.title3)
                            .foregroundStyle(brief.color)
                            .frame(width: 40, height: 40)
                            .background(Color.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(brief.shortLabel) brief")
                }
            }
        }
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}
