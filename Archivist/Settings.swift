import Foundation

/// The keys of the settings in UserDefaults, and their values before the user changes them.
enum Settings {
    static let keepHistory = "keepHistory"
    static let ignoredApps = "ignoredApps"
    static let ignoreTransientContent = "ignoreTransientContent"
    static let ignoreConfidentialContent = "ignoreConfidentialContent"

    static func registerDefaults(in defaults: UserDefaults = .standard) {
        defaults.register(defaults: [
            keepHistory: HistoryRetention.month.rawValue,
            ignoredApps: ["com.apple.Passwords"],
            ignoreTransientContent: true,
            ignoreConfidentialContent: true,
        ])
    }
}

/// How long an item that is not pinned stays in the history.
enum HistoryRetention: String, CaseIterable {
    case day, week, month, year, forever

    var name: String {
        switch self {
        case .day: "1 Day"
        case .week: "1 Week"
        case .month: "1 Month"
        case .year: "1 Year"
        case .forever: "Forever"
        }
    }

    /// Items from before this date are too old.
    func cutOff(from now: Date = .now) -> Date? {
        let component: Calendar.Component? = switch self {
        case .day: .day
        case .week: .weekOfYear
        case .month: .month
        case .year: .year
        case .forever: nil
        }
        return component.flatMap { Calendar.current.date(byAdding: $0, value: -1, to: now) }
    }
}
