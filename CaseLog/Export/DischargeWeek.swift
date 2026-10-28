import Foundation

/// Monday-to-Sunday weeks for the discharge list.
enum DischargeWeek {
    static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = 2 // Monday
        calendar.timeZone = .current
        return calendar
    }

    static func interval(containing date: Date) -> DateInterval {
        let start = calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? calendar.startOfDay(for: date)
        return interval(startingAt: start)
    }

    static func interval(startingAt start: Date) -> DateInterval {
        let end = calendar.date(byAdding: .day, value: 7, to: start) ?? start.addingTimeInterval(7 * 24 * 60 * 60)
        return DateInterval(start: start, end: end)
    }

    static func shifted(_ week: DateInterval, byWeeks weeks: Int) -> DateInterval {
        let start = calendar.date(byAdding: .day, value: 7 * weeks, to: week.start) ?? week.start
        return interval(startingAt: start)
    }

    /// Discharged, not deleted, with a discharge date inside the week; sorted by discharge date then name.
    static func cases(_ all: [SurgicalCase], in week: DateInterval) -> [SurgicalCase] {
        all
            .filter { caseItem in
                guard caseItem.deletedAt == nil, let date = caseItem.dischargeDate else { return false }
                return date >= week.start && date < week.end
            }
            .sorted { lhs, rhs in
                if lhs.dischargeDate != rhs.dischargeDate {
                    return (lhs.dischargeDate ?? .distantPast) < (rhs.dischargeDate ?? .distantPast)
                }
                return lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
            }
    }

    /// "Oct 26 – Nov 1, 2026"
    static func label(for week: DateInterval) -> String {
        let lastDay = calendar.date(byAdding: .day, value: -1, to: week.end) ?? week.end
        let start = week.start.formatted(.dateTime.month(.abbreviated).day())
        let end = lastDay.formatted(.dateTime.month(.abbreviated).day().year())
        return "\(start) – \(end)"
    }
}
