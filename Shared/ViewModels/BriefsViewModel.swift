import Foundation
import Observation

/// Drives the Briefs tab and any other surface that needs availability info
/// for specific (date, kind) pairs (§7.5). Loads a 14-day window on appear;
/// every call site reads through `brief(for:date:)` / `availability(for:date:)`
/// so disabled state stays consistent across the app.
@Observable
final class BriefsViewModel {
    var briefs: [Brief] = []
    var isLoading = false
    var error: String?

    /// Number of days back from today that the grid renders. Matches the
    /// 14×3 grid in `BriefsView`.
    static let windowDays = 14

    /// Builds the descending list of `Date` rows for the grid, with today
    /// at the top.
    var days: [Date] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        return (0..<Self.windowDays).compactMap {
            cal.date(byAdding: .day, value: -$0, to: today)
        }
    }

    func load() async {
        isLoading = true
        error = nil
        defer { isLoading = false }
        guard let from = days.last?.isoDate, let to = days.first?.isoDate else { return }
        do {
            briefs = try await APIClient.shared.listBriefs(from: from, to: to)
        } catch {
            self.error = error.localizedDescription
        }
    }

    func brief(for kind: BriefKind, date: Date) -> Brief? {
        let iso = date.isoDate
        return briefs.first { $0.date == iso && $0.kind == kind }
    }

    func availability(for kind: BriefKind, date: Date) -> BriefAvailability {
        BriefAvailability.from(brief: brief(for: kind, date: date))
    }

    /// Acknowledge a `ready` brief. Falls back to optimistic local-only
    /// acknowledgement if the API call fails, so the unread badge clears even
    /// when the user is offline.
    func acknowledge(brief: Brief) async {
        guard brief.status == .ready else { return }
        if let updated = try? await APIClient.shared.acknowledgeBrief(id: brief.id) {
            replace(brief: updated)
        } else {
            replace(brief: locallyAcknowledged(brief))
        }
    }

    private func replace(brief: Brief) {
        if let idx = briefs.firstIndex(where: { $0.id == brief.id }) {
            briefs[idx] = brief
        }
    }

    private func locallyAcknowledged(_ brief: Brief) -> Brief {
        Brief(
            id: brief.id,
            date: brief.date,
            kind: brief.kind,
            status: .acknowledged,
            title: brief.title,
            body: brief.body,
            references: brief.references,
            invocationId: brief.invocationId,
            generatedAt: brief.generatedAt,
            acknowledgedAt: ISO8601DateFormatter().string(from: Date()),
            revealAt: brief.revealAt,
            windowStart: brief.windowStart,
            windowEnd: brief.windowEnd,
            createdAt: brief.createdAt,
            updatedAt: brief.updatedAt
        )
    }
}
