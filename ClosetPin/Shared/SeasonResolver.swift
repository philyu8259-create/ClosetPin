import Foundation

enum SeasonResolver {
    static func currentSeason(date: Date = Date(), calendar: Calendar = .current) -> SeasonTag {
        let month = calendar.component(.month, from: date)

        switch month {
        case 3...5:
            return .spring
        case 6...8:
            return .summer
        case 9...11:
            return .autumn
        default:
            return .winter
        }
    }
}
