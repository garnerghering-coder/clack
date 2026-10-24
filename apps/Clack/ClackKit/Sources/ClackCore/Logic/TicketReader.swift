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

    public var id: String { "\(date)|\(dep)|\(from)|\(to)" }

    public init(operatorName: String? = nil, trainNumber: String? = nil, date: String, from: String, to: String, dep: String, arr: String? = nil) {
        self.operatorName = operatorName
        self.trainNumber = trainNumber
        self.date = date
        self.from = from
        self.to = to
        self.dep = dep
        self.arr = arr
    }
}

/// Reads trains off SJ's ticket PDFs and receipts, in Swedish and English (docs/TRAIN_ART.md's rule applies here too:
/// nothing guessed). Built from real documents: an SJ ticket has one page per train, with a date line, two "HH:mm
/// Station" lines and a "Tåg/Train N" line, then the operator; an SJ receipt lists "A–B", "Operator, terms" and
/// "10 okt 2026 kl 12:05" for each train, and has no train number. Names, booking numbers and prices are never read.
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
        var out = pages.compactMap(ticketPage)
        if out.isEmpty { out = receipt(pages.joined(separator: "\n")) }
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
        return TicketTrain(
            operatorName: operatorLine.map { String($0.split(separator: ",").first ?? "").trimmingCharacters(in: .whitespaces) },
            trainNumber: number, date: date,
            from: stops[0][2], to: stops[1][2], dep: time(stops[0][0], stops[0][1]), arr: time(stops[1][0], stops[1][1])
        )
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
        return found.first
    }
}
