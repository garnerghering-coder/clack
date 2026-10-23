//
//  Hours.swift
//  Clack
//

import Foundation

/// Opening hours for station amenities (ADDITIONS_01 C2), a port of `packages/shared/src/hours.ts`. A small
/// evaluator for the part of OSM's opening_hours syntax that station shops use: "24/7", weekday lists and ranges,
/// several time spans, spans past midnight, "off"/"closed", and PH (Swedish public holidays). Anything else is
/// "unknown", never a guess. Times are Europe/Stockholm wall-clock.
nonisolated struct Hours: Equatable, Sendable {
    enum Day: Hashable, Sendable {
        /// 0 = Monday ... 6 = Sunday.
        case weekday(Int)
        case publicHoliday
    }

    struct Span: Equatable, Sendable {
        /// Minutes from midnight.
        var start: Int
        /// May exceed 1440 (past midnight).
        var end: Int
    }

    struct Rule: Equatable, Sendable {
        /// Empty = every day.
        var days: Set<Day>
        /// Empty = closed that day.
        var spans: [Span]
    }

    var rules: [Rule]
    var always: Bool
}

nonisolated enum OpenState: String, Sendable {
    case open
    case closingSoon = "closing_soon"
    case closed
    case unknown
}

nonisolated enum OpeningHours {
    private static let dayNames = ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]
    private static let zone = TimeZone(identifier: "Europe/Stockholm") ?? .gmt

    private static let splitter = try! NSRegularExpression(pattern: ";|,\\s+(?=(?:Mo|Tu|We|Th|Fr|Sa|Su|PH)\\b)")
    private static let ruleShape = try! NSRegularExpression(
        pattern: "^((?:(?:Mo|Tu|We|Th|Fr|Sa|Su|PH)(?:-(?:Mo|Tu|We|Th|Fr|Sa|Su))?)(?:\\s*,\\s*(?:Mo|Tu|We|Th|Fr|Sa|Su|PH)(?:-(?:Mo|Tu|We|Th|Fr|Sa|Su))?)*)?\\s*(.*)$"
    )
    private static let timeSpan = try! NSRegularExpression(pattern: "^(\\d{1,2}):(\\d{2})-(\\d{1,2}):(\\d{2})$")

    private static func groups(_ regex: NSRegularExpression, in text: String) -> [String?]? {
        let range = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, range: range) else { return nil }
        return (0..<match.numberOfRanges).map { index in
            let r = match.range(at: index)
            return r.location == NSNotFound ? nil : Range(r, in: text).map { String(text[$0]) }
        }
    }

    /// `text.split(/;|,\s+(?=weekday)/)`.
    private static func splitRules(_ text: String) -> [String] {
        let whole = NSRange(text.startIndex..., in: text)
        var parts: [String] = []
        var last = text.startIndex
        for match in splitter.matches(in: text, range: whole) {
            guard let range = Range(match.range, in: text) else { continue }
            parts.append(String(text[last..<range.lowerBound]))
            last = range.upperBound
        }
        parts.append(String(text[last...]))
        return parts
    }

    /// Parse; nil when the text uses syntax we don't evaluate (shown as "hours unverified").
    static func parse(_ text: String?) -> Hours? {
        guard let text, !text.isEmpty else { return nil }
        let source = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if source == "24/7" { return Hours(rules: [], always: true) }
        var rules: [Hours.Rule] = []
        let parts = splitRules(source).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        for part in parts {
            guard let m = groups(ruleShape, in: part) else { return nil }
            var days: Set<Hours.Day> = []
            let dayText = (m.count > 1 ? m[1] : nil) ?? ""
            for token in dayText.components(separatedBy: ",").map({ $0.trimmingCharacters(in: .whitespaces) }).filter({ !$0.isEmpty }) {
                if token == "PH" {
                    days.insert(.publicHoliday)
                    continue
                }
                let ends = token.components(separatedBy: "-")
                guard let a = dayNames.firstIndex(of: ends[0]) else { return nil }
                let b = ends.count > 1 ? dayNames.firstIndex(of: ends[1]) : a
                guard let b else { return nil }
                var i = a
                while true {
                    days.insert(.weekday(i))
                    if i == b { break }
                    i = (i + 1) % 7
                }
            }
            let times = ((m.count > 2 ? m[2] : nil) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            var spans: [Hours.Span] = []
            if times.lowercased() == "off" || times.lowercased() == "closed" {
                spans = []
            } else if times.isEmpty && !days.isEmpty {
                spans = [Hours.Span(start: 0, end: 1440)]
            } else {
                for t in times.components(separatedBy: ",").map({ $0.trimmingCharacters(in: .whitespaces) }) {
                    guard let tm = groups(timeSpan, in: t), tm.count == 5,
                          let h1 = tm[1].flatMap({ Int($0) }), let m1 = tm[2].flatMap({ Int($0) }),
                          let h2 = tm[3].flatMap({ Int($0) }), let m2 = tm[4].flatMap({ Int($0) }) else { return nil }
                    let start = h1 * 60 + m1
                    var end = h2 * 60 + m2
                    if end <= start { end += 1440 }
                    spans.append(Hours.Span(start: start, end: end))
                }
            }
            rules.append(Hours.Rule(days: days, spans: spans))
        }
        return rules.isEmpty ? nil : Hours(rules: rules, always: false)
    }

    // MARK: Swedish public holidays (helgdagar), the days PH refers to

    /// Days since 1970-01-01 of a civil date (proleptic Gregorian).
    private static func epochDay(_ y: Int, _ m: Int, _ d: Int) -> Int {
        let y2 = m <= 2 ? y - 1 : y
        let era = (y2 >= 0 ? y2 : y2 - 399) / 400
        let yoe = y2 - era * 400
        let doy = (153 * (m + (m > 2 ? -3 : 9)) + 2) / 5 + d - 1
        let doe = yoe * 365 + yoe / 4 - yoe / 100 + doy
        return era * 146_097 + doe - 719_468
    }

    private static func isoDate(epochDay z0: Int) -> String {
        let z = z0 + 719_468
        let era = (z >= 0 ? z : z - 146_096) / 146_097
        let doe = z - era * 146_097
        let yoe = (doe - doe / 1460 + doe / 36_524 - doe / 146_096) / 365
        let doy = doe - (365 * yoe + yoe / 4 - yoe / 100)
        let mp = (5 * doy + 2) / 153
        let d = doy - (153 * mp + 2) / 5 + 1
        let m = mp < 10 ? mp + 3 : mp - 9
        let y = yoe + era * 400 + (m <= 2 ? 1 : 0)
        return String(format: "%04d-%02d-%02d", y, m, d)
    }

    /// Monday = 0.
    private static func weekday(epochDay day: Int) -> Int {
        (((day + 3) % 7) + 7) % 7
    }

    /// The first given weekday (0 = Monday) on or after a day.
    private static func onOrAfter(_ day: Int, weekday wd: Int) -> Int {
        for i in 0..<7 where weekday(epochDay: day + i) == wd { return day + i }
        return day
    }

    private static func easter(_ y: Int) -> (month: Int, day: Int) {
        let a = y % 19, b = y / 100, c = y % 100, d = b / 4, e = b % 4
        let f = (b + 8) / 25, g = (b - f + 1) / 3, h = (19 * a + b - d - g + 15) % 30
        let i = c / 4, k = c % 4, l = (32 + 2 * e + 2 * i - h - k) % 7, m = (a + 11 * h + 22 * l) / 451
        let month = (h + l - 7 * m + 114) / 31
        return (month, ((h + l - 7 * m + 114) % 31) + 1)
    }

    private final class HolidayCache: @unchecked Sendable {
        private let lock = NSLock()
        private var years: [Int: Set<String>] = [:]

        func get(_ year: Int, make: () -> Set<String>) -> Set<String> {
            lock.lock()
            defer { lock.unlock() }
            if let cached = years[year] { return cached }
            let made = make()
            years[year] = made
            return made
        }
    }

    private static let holidayCache = HolidayCache()

    /// Röda dagar plus midsommar-, jul- and nyårsafton, which shops and stations treat as holidays.
    static func swedishHolidays(_ y: Int) -> Set<String> {
        holidayCache.get(y) {
            let (em, ed) = easter(y)
            let e = epochDay(y, em, ed)
            let midsummerEve = onOrAfter(epochDay(y, 6, 20), weekday: 5) - 1
            let days = [
                epochDay(y, 1, 1), epochDay(y, 1, 6), e - 2, e, e + 1, epochDay(y, 5, 1), e + 39, e + 49,
                epochDay(y, 6, 6), midsummerEve, midsummerEve + 1, onOrAfter(epochDay(y, 10, 31), weekday: 5),
                epochDay(y, 12, 24), epochDay(y, 12, 25), epochDay(y, 12, 26), epochDay(y, 12, 31),
            ]
            return Set(days.map(isoDate))
        }
    }

    // MARK: Evaluation

    private static func local(_ ms: Double) -> (date: String, weekday: Int, minute: Int) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        let parts = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: Date(timeIntervalSince1970: ms / 1000))
        let y = parts.year ?? 1970, m = parts.month ?? 1, d = parts.day ?? 1
        return (
            String(format: "%04d-%02d-%02d", y, m, d), weekday(epochDay: epochDay(y, m, d)),
            (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
        )
    }

    /// Spans (minutes from that day's midnight) open on a local date; later rules override earlier ones, as in OSM.
    private static func spansOn(_ hours: Hours, date: String, weekday: Int) -> [Hours.Span] {
        let ph = swedishHolidays(Int(date.prefix(4)) ?? 1970).contains(date)
        var out: [Hours.Span] = []
        for rule in hours.rules {
            let hasPH = hours.rules.contains { $0.days.contains(.publicHoliday) }
            let applies = rule.days.isEmpty || (ph && rule.days.contains(.publicHoliday))
                || (rule.days.contains(.weekday(weekday)) && !(ph && hasPH))
            if applies { out = rule.spans }
        }
        return out
    }

    static func isOpen(_ hours: Hours, at ms: Double) -> Bool {
        if hours.always { return true }
        let now = local(ms)
        if spansOn(hours, date: now.date, weekday: now.weekday).contains(where: { now.minute >= $0.start && now.minute < $0.end }) {
            return true
        }
        // Yesterday's span that runs past midnight.
        let yesterday = local(ms - 86_400_000)
        return spansOn(hours, date: yesterday.date, weekday: yesterday.weekday).contains { $0.end > 1440 && now.minute < $0.end - 1440 }
    }

    /// State at a moment (default rule: "closes soon" = within 30 min), or over a window (layover): open for all of
    /// it, open part of it (closing soon, with when it closes), or closed throughout. Checked minute by minute:
    /// windows are short.
    static func openState(_ text: String?, from: Double, to: Double? = nil, soonMin: Double = 30) -> (state: OpenState, closesAt: Double?) {
        guard let hours = parse(text) else { return (.unknown, nil) }
        if hours.always { return (.open, nil) }
        let to = to ?? from
        let step: Double = 60_000
        let end = to == from ? from + soonMin * 60_000 : to
        let openNow = isOpen(hours, at: from)
        var closesAt: Double?
        var anyOpen = openNow
        var t = from + step
        while t <= end {
            let o = isOpen(hours, at: t)
            if o { anyOpen = true }
            if !o && closesAt == nil && (openNow || anyOpen) { closesAt = t }
            t += step
        }
        if to == from {
            if !openNow { return (.closed, nil) }
            return closesAt == nil ? (.open, nil) : (.closingSoon, closesAt)
        }
        if openNow && closesAt == nil { return (.open, nil) }
        return anyOpen ? (.closingSoon, closesAt) : (.closed, nil)
    }
}
