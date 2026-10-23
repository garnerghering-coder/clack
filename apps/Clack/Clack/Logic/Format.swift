//
//  Format.swift
//  Clack
//

import Foundation

/// Display formatting, a port of `apps/web/src/format.ts`. Times are shown in the station's own time zone, never
/// the phone's. Times are epoch milliseconds (`Instant.ms`).
nonisolated enum Format {
    /// Dates and numbers in the app's language: "tis 21 okt" in Swedish, "Tue 21 Oct" in English.
    static func locale(_ language: Language) -> Locale {
        Locale(identifier: language == .sv ? "sv_SE" : "en_GB")
    }

    private static func calendar(_ tz: String) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: tz) ?? TimeZone(identifier: "Europe/Stockholm") ?? .gmt
        return calendar
    }

    private static func date(_ ms: Double) -> Date {
        Date(timeIntervalSince1970: ms / 1000)
    }

    /// `19:04`, or `7:04 pm` with the 12-hour clock; `--:--` when there is no time.
    static func time(_ ms: Double?, tz: String, clock: ClockFormat) -> String {
        guard let ms else { return "--:--" }
        let parts = calendar(tz).dateComponents([.hour, .minute], from: date(ms))
        let hour = parts.hour ?? 0
        let minute = String(format: "%02d", parts.minute ?? 0)
        if clock == .h12 {
            return "\(hour % 12 == 0 ? 12 : hour % 12):\(minute) \(hour < 12 ? "am" : "pm")"
        }
        return "\(String(format: "%02d", hour)):\(minute)"
    }

    /// "Fri 17 Oct" (adds the year when it isn't the current one).
    static func day(_ ms: Double, tz: String, now: Double = Date.now.timeIntervalSince1970 * 1000, language: Language = .en) -> String {
        let calendar = calendar(tz)
        let sameYear = calendar.component(.year, from: date(ms)) == calendar.component(.year, from: date(now))
        return formatted(ms, tz: tz, language: language, template: sameYear ? "EEEdMMM" : "EEEdMMMy")
            .replacingOccurrences(of: ",", with: "")
    }

    /// "Friday 17 October 2026".
    static func longDate(_ ms: Double, tz: String, language: Language = .en) -> String {
        formatted(ms, tz: tz, language: language, template: "EEEEdMMMMy").replacingOccurrences(of: ",", with: "")
    }

    /// "October 2026".
    static func month(_ ms: Double, tz: String, language: Language = .en) -> String {
        formatted(ms, tz: tz, language: language, template: "MMMMy")
    }

    private static func formatted(_ ms: Double, tz: String, language: Language, template: String) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale(language)
        formatter.timeZone = calendar(tz).timeZone
        formatter.setLocalizedDateFormatFromTemplate(template)
        return formatter.string(from: date(ms))
    }

    /// Local calendar date (`YYYY-MM-DD`) of an instant in a time zone.
    static func localDate(_ ms: Double, tz: String) -> String {
        let parts = calendar(tz).dateComponents([.year, .month, .day], from: date(ms))
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    /// Days between the local dates of two instants: +1 for an arrival after midnight.
    static func dayOffset(from fromMs: Double, fromTz: String, to toMs: Double, toTz: String) -> Int {
        (days(localDate(toMs, tz: toTz)) ?? 0) - (days(localDate(fromMs, tz: fromTz)) ?? 0)
    }

    /// Whole days from 1970-01-01 to a `YYYY-MM-DD` date.
    private static func days(_ iso: String) -> Int? {
        guard let noon = isoToNoonMs(iso) else { return nil }
        return Int((noon / 86_400_000).rounded(.down))
    }

    /// `2h 48m`, `45m`, `1d 3h`.
    static func duration(_ minutes: Double) -> String {
        let h = Int((minutes / 60).rounded(.down))
        let m = Int(minutes.truncatingRemainder(dividingBy: 60).rounded())
        if h >= 24 { return "\(h / 24)d \(h % 24)h" }
        return h > 0 ? "\(h)h \(String(format: "%02d", m))m" : "\(m)m"
    }

    /// `455 km` or `283 mi`; `—` when unknown.
    static func distance(_ meters: Double?, unit: DistanceUnit, language: Language = .en) -> String {
        guard let meters else { return "—" }
        let value = unit == .mi ? meters / 1609.344 : meters / 1000
        let formatter = NumberFormatter()
        formatter.locale = locale(language)
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return "\(formatter.string(from: NSNumber(value: value.rounded())) ?? "") \(unit.rawValue)"
    }

    /// `+8`, `−2` (a real minus sign), `0`, `—` when unknown.
    static func delay(_ min: Int?) -> String {
        guard let min else { return "—" }
        if min == 0 { return "0" }
        return min > 0 ? "+\(min)" : "−\(abs(min))"
    }

    static func todayIso(tz: String = "Europe/Stockholm") -> String {
        localDate(Date.now.timeIntervalSince1970 * 1000, tz: tz)
    }

    static func addDaysIso(_ iso: String, days: Int) -> String? {
        guard let noon = isoToNoonMs(iso) else { return nil }
        let shifted = noon + Double(days) * 86_400_000
        return localDate(shifted, tz: "UTC")
    }

    /// Noon UTC of a `YYYY-MM-DD` date, in epoch ms; nil when it isn't a date.
    static func isoToNoonMs(_ iso: String) -> Double? {
        Instant.parse("\(iso)T12:00:00Z").map { $0.timeIntervalSince1970 * 1000 }
    }
}
