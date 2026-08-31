import Foundation

public enum HabitDateText {
    public static func weekdayName(for weekday: Int, narrow: Bool = false) -> String {
        guard (0...6).contains(weekday) else { return "" }
        let formatter = DateFormatter()
        formatter.locale = AppLanguage.selected.locale
        let symbols = narrow
            ? formatter.veryShortStandaloneWeekdaySymbols
            : formatter.shortStandaloneWeekdaySymbols
        return symbols?[weekday].capitalizingFirstLetter ?? ""
    }
}
