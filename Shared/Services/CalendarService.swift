import Foundation
import EventKit
import Observation

/// EventKit wrapper that owns calendar permissions and exposes a tiny
/// today-only slice for the Feed: the next upcoming event (header peek) and
/// today's already-finished events (rendered as past `FeedEvent.calendarEvent`
/// rows). Lookahead is 2 days so the peek can reach into tomorrow morning if
/// today has no remaining events.
@Observable
final class CalendarService {
    private let store = EKEventStore()

    /// Cached authorization snapshot. Updated on every `requestAccessIfNeeded`
    /// and `refresh` so the header CTA stays in sync with system Settings
    /// changes.
    private(set) var authStatus: EKAuthorizationStatus = EKEventStore.authorizationStatus(for: .event)

    /// Next upcoming event across all calendars within the 2-day lookahead.
    private(set) var nextEvent: EKEvent?

    /// Today's events that have already ended — surfaced in the EventList
    /// under the "You" filter category (PR 4).
    private(set) var pastTodayEvents: [EKEvent] = []

    var hasAccess: Bool { authStatus == .fullAccess }

    /// Triggers the iOS permission prompt only on first launch. After the
    /// user has decided, this is a no-op so we don't annoy them on every
    /// `load()`. Always re-reads `authorizationStatus` so a Settings-app
    /// flip is reflected.
    func requestAccessIfNeeded() async {
        let current = EKEventStore.authorizationStatus(for: .event)
        authStatus = current
        guard current == .notDetermined else { return }
        do {
            let granted = try await store.requestFullAccessToEvents()
            authStatus = granted ? .fullAccess : .denied
        } catch {
            authStatus = .denied
        }
    }

    /// Cheap local-store query — safe to run on every 10s polling tick.
    /// Bails when the user hasn't granted access so we don't spin.
    func refresh() async {
        // Re-read in case the user toggled access in Settings while the app
        // was foregrounded (system delivers `EKEventStoreChanged` but we
        // don't subscribe yet — see plan §3.3).
        authStatus = EKEventStore.authorizationStatus(for: .event)
        guard hasAccess else {
            nextEvent = nil
            pastTodayEvents = []
            return
        }

        let cal = Calendar(identifier: .gregorian)
        let startOfDay = cal.startOfDay(for: Date())
        guard let endOfWindow = cal.date(byAdding: .day, value: 2, to: startOfDay),
              let endOfToday = cal.date(byAdding: .day, value: 1, to: startOfDay) else { return }

        let predicate = store.predicateForEvents(withStart: startOfDay, end: endOfWindow, calendars: nil)
        let events = store.events(matching: predicate).sorted { $0.startDate < $1.startDate }

        let now = Date()
        nextEvent = events.first { $0.startDate > now }
        pastTodayEvents = events.filter {
            $0.endDate < now && $0.startDate >= startOfDay && $0.startDate < endOfToday
        }
    }
}
