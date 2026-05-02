import Foundation
import Observation

/// Computes the user's daily Rosary streak from `RosaryState`'s per-day
/// UserDefaults keys (`rosary-YYYY-MM-DD`, populated in
/// `FeedViewModel.RosaryState`). A day counts toward the streak when all
/// five mysteries were checked; today is included once complete so the
/// chip bumps immediately rather than waiting until tomorrow's rollover.
///
/// Storage is local-only — UserDefaults isn't iCloud-synced, so streaks
/// reset on a new device. See `Plans/FEED_RESTRUCTURE_PLAN.md` §5.5.
@Observable
final class StreakService {
    private(set) var rosary: Int = 0

    private let calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "America/New_York") ?? .current
        return cal
    }()

    private let keyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(identifier: "America/New_York")
        return f
    }()

    func recompute(today: Date = Date()) {
        var streak = 0
        var cursor = calendar.startOfDay(for: today)
        while completedRosary(on: cursor) {
            streak += 1
            guard let prev = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = prev
            if streak > 365 { break }
        }
        rosary = streak
    }

    private func completedRosary(on date: Date) -> Bool {
        let key = "rosary-\(keyFormatter.string(from: date))"
        let saved = UserDefaults.standard.array(forKey: key) as? [Int] ?? []
        return Set(saved).count >= 5
    }
}
