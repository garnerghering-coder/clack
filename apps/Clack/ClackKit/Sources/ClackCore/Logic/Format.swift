//
//  Format.swift
//  Clack
//

import Foundation

/// Display formatting, a port of `apps/web/src/format.ts`. Times are shown in the station's own time zone, never
/// the phone's. Times are epoch milliseconds (`Instant.ms`).
public nonisolated enum Format {
    /// Dates and numbers in the app's language: "tis 21 okt" in Swedish, "Tue 21 Oct" in English (British English:
    /// day before month, 24-hour), each other language with the country it is chiefly read in.
    public static func locale(_ language: Language) -> Locale {
        Locale(identifier: localeIdentifier(language))
    }

    /// The identifier `locale` uses ("nb_NO" for Norwegian Bokmål).
    public static func localeIdentifier(_ language: Language) -> String {
        switch language {
        case .en, .unknown: "en_GB"
        case .sv: "sv_SE"
        case .da: "da_DK"
        case .nb: "nb_NO"
        case .fi: "fi_FI"
        case .de: "de_DE"
        case .pl: "pl_PL"
        case .fr: "fr_FR"
        }
    }

    /// The zone used when nothing says which one a place is in (Sweden, which most trips are in). Norway has the same
    /// clock; Finland (Europe/Helsinki) is one hour ahead, so a Finnish place must bring its own.
    public static let defaultZone = "Europe/Stockholm"

    /// `tz` when it is a zone this phone knows, else `defaultZone`: what every formatter here falls back to.
    public static func zone(_ tz: String?) -> String {
        if let tz, TimeZone(identifier: tz) != nil { return tz }
        return defaultZone
    }

    /// The zone of a country's stations (ISO 3166 alpha-2, as `StationHit.country`), `defaultZone` when unknown.
    /// Use a station's or leg's own `tz` where there is one: this is for places that only know the country.
    public static func zone(country: String?) -> String {
        switch country {
        case "FI": return "Europe/Helsinki"
        case "NO": return "Europe/Oslo"
        default: return defaultZone
        }
    }

    /// The zone of a station from its id, which carries the country (`fi:HKI`, `no:...`; Swedish ids have no prefix).
    public static func zone(stationId: String?) -> String {
        guard let stationId else { return defaultZone }
        if stationId.hasPrefix("fi:") { return zone(country: "FI") }
        if stationId.hasPrefix("no:") || stationId.hasPrefix("76") { return zone(country: "NO") }
        return defaultZone
    }

    private static func calendar(_ tz: String) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: zone(tz)) ?? .gmt
        return calendar
    }

    private static func date(_ ms: Double) -> Date {
        Date(timeIntervalSince1970: ms / 1000)
    }

    /// `19:04`, or `7:04 pm` with the 12-hour clock; `--:--` when there is no time.
    public static func time(_ ms: Double?, tz: String, clock: ClockFormat) -> String {
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
    public static func day(_ ms: Double, tz: String, now: Double = Date.now.timeIntervalSince1970 * 1000, language: Language = .en) -> String {
        let calendar = calendar(tz)
        let sameYear = calendar.component(.year, from: date(ms)) == calendar.component(.year, from: date(now))
        let text = formatted(ms, tz: tz, language: language, template: sameYear ? "EEEdMMM" : "EEEdMMMy")
        switch language {
        case .en, .unknown, .sv:
            // No full stops in Swedish: it abbreviates "nov." and "sön.", which doubled the stop where a day ends a
            // sentence ("Inget tåg SJ 421 sön 8 nov..", user test 2026-11-07, run 2). No comma in English ("Sun 9 Nov
            // 2025"). Only these two: elsewhere the stops are part of the date ("ma 9.11." in Finnish, "So. 9. Nov." in
            // German, "søn. 9. nov." in Danish), and taking them out left "ma 911" (build 86 check).
            return text.replacingOccurrences(of: ",", with: "").replacingOccurrences(of: ".", with: "")
        case .da, .nb, .fi, .de, .pl, .fr:
            return text
        }
    }

    /// "Friday 17 October 2026".
    public static func longDate(_ ms: Double, tz: String, language: Language = .en) -> String {
        withoutComma(formatted(ms, tz: tz, language: language, template: "EEEEdMMMMy"), language: language)
    }

    /// "1 January 2020" (no weekday).
    public static func fullDate(_ ms: Double, tz: String, language: Language = .en) -> String {
        withoutComma(formatted(ms, tz: tz, language: language, template: "dMMMMy"), language: language)
    }

    /// English and Swedish drop the comma after the weekday ("Friday 17 October 2026"); the other languages keep
    /// their own punctuation ("Sonntag, 9. November 2025", "niedziela, 9 listopada 2025").
    private static func withoutComma(_ text: String, language: Language) -> String {
        switch language {
        case .en, .unknown, .sv: text.replacingOccurrences(of: ",", with: "")
        case .da, .nb, .fi, .de, .pl, .fr: text
        }
    }

    /// "October 2026".
    public static func month(_ ms: Double, tz: String, language: Language = .en) -> String {
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
    public static func localDate(_ ms: Double, tz: String) -> String {
        let parts = calendar(tz).dateComponents([.year, .month, .day], from: date(ms))
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    /// Days between the local dates of two instants: +1 for an arrival after midnight.
    public static func dayOffset(from fromMs: Double, fromTz: String, to toMs: Double, toTz: String) -> Int {
        (days(localDate(toMs, tz: toTz)) ?? 0) - (days(localDate(fromMs, tz: fromTz)) ?? 0)
    }

    /// Whole days from 1970-01-01 to a `YYYY-MM-DD` date.
    private static func days(_ iso: String) -> Int? {
        guard let noon = isoToNoonMs(iso) else { return nil }
        return Int((noon / 86_400_000).rounded(.down))
    }

    /// Minutes for a sentence: "14 min", "1 h 44 min" (user test 2026-11-07: "104 min" made someone stop and count).
    public static func minutesWords(_ minutes: Int) -> String {
        guard minutes >= 60 else { return "\(minutes) min" }
        let m = minutes % 60
        return m == 0 ? "\(minutes / 60) h" : "\(minutes / 60) h \(m) min"
    }

    /// `2h 48m`, `45m`, `1d 3h`; in Swedish `2 h 48 min`, `45 min`, `1 d 3 h` (the user test of 2026-11-07 read "2h 48m"
    /// in the Swedish app as English); in the other languages Foundation's abbreviated units for the language.
    public static func duration(_ minutes: Double, language: Language = .en) -> String {
        let h = Int((minutes / 60).rounded(.down))
        let m = Int(minutes.truncatingRemainder(dividingBy: 60).rounded())
        switch language {
        case .sv:
            if h >= 24 { return "\(h / 24) d \(h % 24) h" }
            return h > 0 ? "\(h) h \(String(format: "%02d", m)) min" : "\(m) min"
        case .en, .unknown:
            if h >= 24 { return "\(h / 24)d \(h % 24)h" }
            return h > 0 ? "\(h)h \(String(format: "%02d", m))m" : "\(m)m"
        case .da, .nb, .fi, .de, .pl, .fr:
            // The phone's own abbreviations for the language (CLDR): "2 t, 5 min" in Norwegian, "2 Std., 5 Min." in
            // German, "2 godz. i 5 min" in Polish; none made up here.
            let units: Set<Duration.UnitsFormatStyle.Unit> = h >= 24 ? [.days, .hours] : h > 0 ? [.hours, .minutes] : [.minutes]
            let seconds = h >= 24 ? Int64(h) * 3600 : Int64(h) * 3600 + Int64(m) * 60
            return Duration.seconds(seconds).formatted(.units(allowed: units, width: .abbreviated).locale(locale(language)))
        }
    }

    /// `455 km` or `283 mi`; `—` when unknown.
    public static func distance(_ meters: Double?, unit: DistanceUnit, language: Language = .en) -> String {
        guard let meters else { return unknown }
        let value = unit == .mi ? meters / 1609.344 : meters / 1000
        let formatter = NumberFormatter()
        formatter.locale = locale(language)
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return "\(formatter.string(from: NSNumber(value: value.rounded())) ?? "") \(unit.rawValue)"
    }

    /// A number in the app's language: "16.5" in English, "16,5" in German, Polish, Finnish, Swedish, with the
    /// language's grouping. `fraction` is how many decimals at most, `minFraction` at least ("0.8", "2").
    public static func number(_ value: Double, fraction: Int = 1, minFraction: Int = 0, language: Language = .en) -> String {
        let formatter = NumberFormatter()
        formatter.locale = locale(language)
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = min(minFraction, fraction)
        formatter.maximumFractionDigits = fraction
        return formatter.string(from: NSNumber(value: value)) ?? String(value)
    }

    /// What an unknown value shows, everywhere: an em dash.
    public static let unknown = "—"

    /// The separator between facts on one line.
    public static let separator = " · "

    /// Facts on one line, "SJ 529 · Platform 4 · 2h 48m": the empty and missing ones left out.
    public static func join(_ parts: [String?], separator: String = Format.separator) -> String {
        parts.compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: separator)
    }

    /// A train as people say it: the operator's name and the train number, "SJ 529"; either alone when the other is
    /// unknown, and "" when both are.
    public static func service(_ operatorName: String?, _ number: String?) -> String {
        join([operatorName, number], separator: " ")
    }

    /// `+8 min`, `−2 min` (a real minus sign), `0`, `—` when unknown. With its unit, so a delay can't be read as a
    /// day ("+1") or a platform (designer, 2026-11-14: "+1", "28m", "4.5 min" all meant different things).
    public static func delay(_ min: Int?) -> String {
        guard let min else { return unknown }
        if min == 0 { return "0" }
        return min > 0 ? "+\(min) min" : "−\(abs(min)) min"
    }

    public static func todayIso(tz: String = Format.defaultZone) -> String {
        localDate(Date.now.timeIntervalSince1970 * 1000, tz: tz)
    }

    public static func addDaysIso(_ iso: String, days: Int) -> String? {
        guard let noon = isoToNoonMs(iso) else { return nil }
        let shifted = noon + Double(days) * 86_400_000
        return localDate(shifted, tz: "UTC")
    }

    /// Midnight UTC of a `YYYY-MM-DD` date, in epoch ms (what JavaScript's `Date.parse` gives); nil when it isn't a date.
    public static func isoToMidnightMs(_ iso: String) -> Double? {
        Instant.parse("\(iso)T00:00:00Z").map { $0.timeIntervalSince1970 * 1000 }
    }

    /// Noon UTC of a `YYYY-MM-DD` date, in epoch ms; nil when it isn't a date.
    public static func isoToNoonMs(_ iso: String) -> Double? {
        Instant.parse("\(iso)T12:00:00Z").map { $0.timeIntervalSince1970 * 1000 }
    }
}

extension Format {
    /// The platforms of a change, saying only what is known (designer, 2026-11-14: "Platform — → 9"): both, the
    /// arrival one, the departure one, or nothing.
    @MainActor
    public static func changeTracks(_ l10n: L10n, arrival: String?, departure: String?) -> String? {
        switch (arrival?.isEmpty == false ? arrival : nil, departure?.isEmpty == false ? departure : nil) {
        case let (a?, d?): l10n.t("connection.tracks", ["from": a, "to": d])
        case let (a?, nil): l10n.t("connection.trackArrive", ["n": a])
        case let (nil, d?): l10n.t("connection.trackLeave", ["n": d])
        case (nil, nil): nil
        }
    }
}

