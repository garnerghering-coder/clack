//
//  TicketReader.swift
//  Clack
//

import Foundation
#if canImport(PDFKit)
import PDFKit
#endif

/// One train read off a ticket or receipt. Only what the document says: nothing is filled in from elsewhere.
public nonisolated struct TicketTrain: Hashable, Sendable, Identifiable {
    public var operatorName: String?
    /// Absent on receipts.
    public var trainNumber: String?
    /// YYYY-MM-DD.
    public var date: String
    public var from: String
    public var to: String
    /// HH:mm, as printed (the boarding station's own clock).
    public var dep: String
    public var arr: String?
    /// The coach ("Vagn 16", "Carriage 11") and seat ("Plats 37", "Seat 105") when the ticket has a seat reservation.
    public var coach: String?
    public var seat: String?
    /// Who issued the ticket: a DB ticket's legs inside Germany have no timetable here (the import says so).
    public var issuer: Issuer = .sj

    public enum Issuer: String, Hashable, Sendable { case sj, dsb, db }

    public var id: String { "\(date)|\(dep)|\(from)|\(to)" }

    public init(operatorName: String? = nil, trainNumber: String? = nil, date: String, from: String, to: String, dep: String, arr: String? = nil, coach: String? = nil, seat: String? = nil, issuer: Issuer = .sj) {
        self.issuer = issuer
        self.operatorName = operatorName
        self.trainNumber = trainNumber
        self.date = date
        self.from = from
        self.to = to
        self.dep = dep
        self.arr = arr
        self.coach = coach
        self.seat = seat
    }
}

/// Reads trains off SJ's ticket PDFs and receipts, in Swedish and English, and DSB and DB tickets (`dsb`, `db` below) (docs/TRAIN_ART.md's rule applies here too:
/// nothing guessed). Built from real documents: an SJ ticket has one page per train, with a date line, two "HH:mm
/// Station" lines and a "Tåg/Train N" line, then the operator; an SJ receipt lists "A–B", "Operator, terms" and
/// "10 okt 2026 kl 12:05" for each train, and has no train number. A ticket with a seat reservation has "Vagn 16" and
/// "Plats 37" ("Carriage 11", "Seat 105") after the train line, on two lines or one; one without says "Ingen
/// platsreservation" ("No seat reservation"). Names, booking numbers and prices are never read.
public nonisolated enum TicketReader {
    // MARK: Files

    /// The text of each page of a PDF.
    public static func pdfPages(_ data: Data) -> [String] {
        #if canImport(PDFKit)
        guard let doc = PDFDocument(data: data) else { return [] }
        return (0..<doc.pageCount).map { doc.page(at: $0)?.string ?? "" }
        #else
        // No PDFKit (watchOS): no pages, so no trains; tickets are read on the phone.
        return []
        #endif
    }

    /// The PDF attached to an .eml file (SJ mails the tickets that way), if there is one.
    public static func pdf(fromEmail data: Data) -> Data? {
        let text = String(decoding: data, as: UTF8.self).replacingOccurrences(of: "\r\n", with: "\n")
        guard let head = text.range(of: "\n\n"),
              let boundary = firstMatch(#"boundary="?([^"\s;]+)"?"#, in: String(text[..<head.lowerBound]))?.first else { return nil }
        for part in text.components(separatedBy: "--" + boundary) {
            guard let split = part.range(of: "\n\n") else { continue }
            let header = String(part[..<split.lowerBound]).lowercased()
            guard header.contains(".pdf") || header.contains("application/pdf"), header.contains("base64") else { continue }
            let body = String(part[split.upperBound...])
            if let decoded = Data(base64Encoded: body, options: .ignoreUnknownCharacters), !decoded.isEmpty { return decoded }
        }
        return nil
    }

    /// The trains in a file: a PDF, or an .eml with a PDF attached. Empty when it isn't a ticket Clack can read.
    public static func trains(inFile data: Data, name: String) -> [TicketTrain] {
        let pdf: Data? = name.lowercased().hasSuffix(".eml") ? Self.pdf(fromEmail: data) : data
        guard let pdf else { return [] }
        return trains(fromPages: pdfPages(pdf))
    }

    // MARK: Text

    public static func trains(fromPages pages: [String]) -> [TicketTrain] {
        let all = pages.joined(separator: "\n")
        var out: [TicketTrain]
        if all.contains("Print Selv-billet") {
            out = dsb(pages)
        } else if all.contains("Online-Ticket"), all.contains("Halt Datum Zeit Gleis Produkte") {
            out = db(all)
        } else {
            out = pages.compactMap(ticketPage)
            if out.isEmpty { out = receipt(all) }
        }
        var seen = Set<String>()
        return out.filter { seen.insert($0.id).inserted }
    }

    private static let months: [String: Int] = [
        "jan": 1, "feb": 2, "mar": 3, "apr": 4, "maj": 5, "may": 5, "jun": 6, "jul": 7, "aug": 8, "sep": 9,
        "okt": 10, "oct": 10, "nov": 11, "dec": 12,
    ]

    private static func lines(_ text: String) -> [String] {
        text.split(separator: "\n").map { $0.replacingOccurrences(of: "\u{FFFC}", with: "").trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    private static func firstMatch(_ pattern: String, in text: String) -> [String]? {
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let m = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) else { return nil }
        return (1..<m.numberOfRanges).compactMap { Range(m.range(at: $0), in: text).map { String(text[$0]) } }
    }

    private static func iso(day: String, month: String, year: String) -> String? {
        guard let m = months[String(month.lowercased().prefix(3))], let d = Int(day), let y = Int(year) else { return nil }
        return String(format: "%04d-%02d-%02d", y, m, d)
    }

    private static func time(_ h: String, _ m: String) -> String { String(format: "%02d:%@", Int(h) ?? 0, m) }

    private static let seatLine = #"^(Vagn|Carriage|Plats|Seat|Ingen platsreservation|No seat reservation)\b"#

    /// One page of an SJ ticket is one train.
    private static func ticketPage(_ page: String) -> TicketTrain? {
        let l = lines(page)
        guard let dateAt = l.firstIndex(where: { firstMatch(#"^\p{L}+,?\s*\d{1,2}\s+\p{L}+\s+\d{4}$"#, in: $0) != nil }),
              let d = firstMatch(#"(\d{1,2})\s+(\p{L}+)\s+(\d{4})$"#, in: l[dateAt]),
              let date = iso(day: d[0], month: d[1], year: d[2]) else { return nil }
        let after = Array(l[(dateAt + 1)...])
        let stops = after.prefix(2).compactMap { firstMatch(#"^(\d{1,2}):(\d{2})\s+(.+)$"#, in: $0) }
        guard stops.count == 2,
              let trainAt = after.firstIndex(where: { firstMatch(#"^(Tåg|Train)\s+\d+\b"#, in: $0) != nil }),
              let number = firstMatch(#"^(?:Tåg|Train)\s+(\d+)"#, in: after[trainAt])?.first else { return nil }
        let operatorLine = after[(trainAt + 1)...].first { firstMatch(seatLine, in: $0) == nil }
        let seatLines = after[(trainAt + 1)...].prefix { firstMatch(seatLine, in: $0) != nil }
        let place = seat(in: Array(seatLines))
        return TicketTrain(
            operatorName: operatorLine.map { String($0.split(separator: ",").first ?? "").trimmingCharacters(in: .whitespaces) },
            trainNumber: number, date: date,
            from: stops[0][2], to: stops[1][2], dep: time(stops[0][0], stops[0][1]), arr: time(stops[1][0], stops[1][1]),
            coach: place.coach, seat: place.seat
        )
    }

    /// The coach and seat in the lines right after "Tåg N": "Vagn 16" and "Plats 37" on their own lines, or "Vagn 4
    /// Plats 23" on one. Only a value with a digit in it counts ("12A" does, a word does not).
    static func seat(in lines: [String]) -> (coach: String?, seat: String?) {
        func value(_ words: String) -> String? {
            for line in lines {
                guard let raw = firstMatch(#"(?i)\b(?:"# + words + #")\s*:?\s+([0-9A-Za-z]{1,8})\b"#, in: line)?.first,
                      raw.contains(where: \.isNumber) else { continue }
                return raw
            }
            return nil
        }
        return (value("Vagn|Carriage"), value("Plats|Seat"))
    }

    /// An SJ receipt: no train number, only the stations, the operator and the departure.
    private static func receipt(_ text: String) -> [TicketTrain] {
        let l = lines(text)
        guard let start = l.firstIndex(where: { $0 == "Din resa" || $0 == "Your journey" }) else { return [] }
        var out: [TicketTrain] = []
        var i = start + 1
        while i + 2 < l.count {
            if let route = firstMatch(#"^(.+)–(.+)$"#, in: l[i]),
               let when = firstMatch(#"^(\d{1,2})\s+(\p{L}+)\.?\s+(\d{4})\s+(?:kl|at)\s+(\d{1,2}):(\d{2})$"#, in: l[i + 2]),
               let date = iso(day: when[0], month: when[1], year: when[2]) {
                out.append(TicketTrain(
                    operatorName: String(l[i + 1].split(separator: ",").first ?? "").trimmingCharacters(in: .whitespaces),
                    trainNumber: nil, date: date, from: route[0], to: route[1], dep: time(when[3], when[4]), arr: nil
                ))
                i += 3
            } else {
                i += 1
            }
        }
        return out
    }

    // MARK: DSB and DB

    /// "Kolding St." and "Fredericia st" as the timetable names them ("Kolding", "Fredericia").
    static func stationName(_ printed: String) -> String {
        printed.replacingOccurrences(of: #"\s+[Ss]t\.?$"#, with: "", options: .regularExpression)
    }

    /// A DSB "Print Selv-billet" (Danish). Page 2, "Din Rejseplan", has the date ("Dato: 06.11.25") and under
    /// "Detaljer" the stations two by two (a leg's start and end), then each leg's "Afg: 18:01" and "Ank: 20:02", and
    /// one "InterCity-tog 50169 til Fredericia St." per leg ("Regional-tog", "IC-Lyntog"). Page 1 prints "Tognr
    /// InterCityLyn 910" with "Vognnr. 63" and "Pladsnr. 24" when a seat is reserved. Names and ID numbers on the ticket
    /// are never read.
    private static func dsb(_ pages: [String]) -> [TicketTrain] {
        let all = pages.joined(separator: "\n")
        guard let d = firstMatch(#"Dato:\s*(\d{2})\.(\d{2})\.(\d{2})"#, in: all), let day = Int(d[0]), let month = Int(d[1]), let yy = Int(d[2]),
              let detailsAt = all.range(of: "Detaljer") else { return [] }
        let date = String(format: "%04d-%02d-%02d", 2000 + yy, month, day)
        let details = String(all[detailsAt.upperBound...])
        let l = lines(details)
        let stations = l.prefix { !$0.hasPrefix("Afg:") && !$0.hasPrefix("Ank:") }.map(stationName)
        let deps = allMatches(#"Afg:\s*(\d{1,2}):(\d{2})"#, in: details).map { time($0[0], $0[1]) }
        let arrs = allMatches(#"Ank:\s*(\d{1,2}):(\d{2})"#, in: details).map { time($0[0], $0[1]) }
        let numbers = allMatches(#"[\p{L}-]*tog\s+(\d+)\s+til\b"#, in: details).map { $0[0] }
        let count = stations.count / 2
        guard count > 0, deps.count >= count, arrs.count >= count else { return [] }
        // The reserved seat belongs to the train page 1 names; a one-train ticket's seat is that train's.
        let seatTrain = firstMatch(#"Tognr\s+\S+\s+(\d+)"#, in: all)?.first
        let coach = firstMatch(#"Vognnr\.?\s*(\w{1,8})"#, in: all)?.first.flatMap { $0.contains(where: \.isNumber) ? $0 : nil }
        let seat = firstMatch(#"Pladsnr\.?\s*(\w{1,8})"#, in: all)?.first.flatMap { $0.contains(where: \.isNumber) ? $0 : nil }
        return (0..<count).map { i in
            let number = numbers.indices.contains(i) ? numbers[i] : nil
            let seated = seatTrain.map { $0 == number } ?? (count == 1)
            return TicketTrain(
                trainNumber: number, date: date, from: stations[2 * i], to: stations[2 * i + 1], dep: deps[i], arr: arrs[i],
                coach: seated ? coach : nil, seat: seated ? seat : nil, issuer: .dsb
            )
        }
    }

    /// A DB "Online-Ticket" (German). Its table "Halt / Datum / Zeit / Gleis / Produkte" reads, per leg: the two
    /// stations, two dates ("15.10."), "ab 18:10" and "an 18:27", up to two platforms, then the train: "IC 5764", or a
    /// line with the number in brackets ("RE 8 (11429)", "NBE RB82" over "(82200)"). The year comes from "Einfache Fahrt
    /// am 15.10.2023". A leg that runs inside Germany is read like the rest; finding no timetable for it is the import's
    /// to say.
    private static func db(_ text: String) -> [TicketTrain] {
        guard let y = firstMatch(#"\bam\s+\d{1,2}\.\d{1,2}\.(\d{4})"#, in: text)?.first ?? firstMatch(#"Gültigkeit:\s*\d{1,2}\.\d{1,2}\.(\d{4})"#, in: text)?.first,
              let tableAt = text.range(of: "Halt Datum Zeit Gleis Produkte") else { return [] }
        let l = lines(String(text[tableAt.upperBound...]))
        var out: [TicketTrain] = []
        for i in l.indices where i >= 4 && i + 1 < l.count {
            guard let dep = firstMatch(#"^ab\s+(\d{1,2}):(\d{2})$"#, in: l[i]), let arr = firstMatch(#"^an\s+(\d{1,2}):(\d{2})$"#, in: l[i + 1]),
                  let day = firstMatch(#"^(\d{1,2})\.(\d{1,2})\.$"#, in: l[i - 2]), let d = Int(day[0]), let m = Int(day[1]) else { continue }
            // After the times: platforms (short, with a digit), then the train, its number maybe on the next line.
            var j = i + 2
            while j < l.count, j < i + 4, firstMatch(#"^\d{1,2}[a-z]?$"#, in: l[j]) != nil { j += 1 }
            guard j < l.count else { continue }
            var product = l[j]
            if j + 1 < l.count, firstMatch(#"^\(\d+\)$"#, in: l[j + 1]) != nil { product += " " + l[j + 1] }
            let number = firstMatch(#"\((\d+)\)"#, in: product)?.first ?? firstMatch(#"(\d+)$"#, in: product)?.first
            out.append(TicketTrain(
                trainNumber: number, date: String(format: "%04d-%02d-%02d", Int(y) ?? 0, m, d),
                from: stationName(l[i - 4]), to: stationName(l[i - 3]), dep: time(dep[0], dep[1]), arr: time(arr[0], arr[1]), issuer: .db
            ))
        }
        return out
    }

    private static func allMatches(_ pattern: String, in text: String) -> [[String]] {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        return regex.matches(in: text, range: NSRange(text.startIndex..., in: text)).map { m in
            (1..<m.numberOfRanges).compactMap { Range(m.range(at: $0), in: text).map { String(text[$0]) } }
        }
    }

    // MARK: Matching

    /// Which trip in the timetable is this train? By departure minute at the boarding station (and arrival, when the
    /// ticket has one); the train number only breaks a tie. SJ's printed numbers can differ from the timetable's for
    /// regional trains (a ticket's 7225 is the timetable's 7205), so the number is never required.
    /// `results` are the search results for the ticket's two stations on its date.
    public static func pick(_ results: [TripResult], for train: TicketTrain) -> TripResult? {
        func clock(_ stop: StopRef) -> String { Format.time(stop.time, tz: stop.tz, clock: .h24) }
        var found = results.filter { clock($0.from) == train.dep }
        if let arr = train.arr, found.contains(where: { clock($0.to) == arr }) { found = found.filter { clock($0.to) == arr } }
        if found.count > 1, let number = train.trainNumber,
           let same = found.first(where: { $0.trainNumber == number || $0.alsoKnownAs.contains(number) }) { return same }
        if let first = found.first { return first }
        // Nothing at the printed minute: the train with the ticket's number within two minutes of it (a timetable
        // adjusted after the ticket was sold, or an archive copy taken before the change). Never by time alone.
        guard let number = train.trainNumber, let want = minutes(train.dep) else { return nil }
        return results.first { r in
            guard r.trainNumber == number || r.alsoKnownAs.contains(number), let got = minutes(clock(r.from)) else { return false }
            let diff = abs(got - want)
            return min(diff, 24 * 60 - diff) <= 2
        }
    }

    /// "HH:mm" as minutes after midnight.
    private static func minutes(_ hhmm: String) -> Int? {
        let parts = hhmm.split(separator: ":").compactMap { Int($0) }
        return parts.count == 2 ? parts[0] * 60 + parts[1] : nil
    }
}
