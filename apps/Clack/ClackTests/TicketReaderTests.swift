//
//  TicketReaderTests.swift
//  ClackTests
//
//  The texts are what PDFKit read from real SJ tickets and receipts (name, booking and ticket numbers removed).
//

import Foundation
import Testing
@testable import Clack
@testable import ClackCore

private let swedishTicket = [
    "Jönköping Central–Kolding\nXX\nSJ Prio-medlem: Prio\nBokningsnr: AAAAAAAA\nBiljettnr: 1\n\u{FFFC}\nBiljett 1 av 2\n\u{FFFC}\nLördag, 10 oktober 2026\n\u{FFFC}\n12:05 Jönköping Central\n12:38 Nässjö Central\n\u{FFFC}\nTåg 7225\n\u{FFFC}\nIngen platsreservation\nVästtrafik\nUngdom, 2 klass, kan ej återbetalas\nDin resa\n\u{FFFC}\nPlant insteg på tåget\nKöp- och resevillkor\n",
    "Jönköping Central–Kolding\nXX\nSJ Prio-medlem: Prio\nBokningsnr: AAAAAAAA\nBiljettnr: 22SC9F-00001 CIV issuer <1174>\n\u{FFFC}\nBiljett 2 av 2\n\u{FFFC}\nLördag, 10 oktober 2026\n\u{FFFC}\n13:32 Nässjö Central\n18:52 Kolding\n\u{FFFC}\nTåg 307\n\u{FFFC}\nVagn 16\n\u{FFFC}\nPlats 37\nSnälltåget, CIV <3051>\nUngdom, Sittplats, kan ej ombokas eller återbetalas.\n",
]

private let englishTicket = [
    "Kolding–Jönköping Central\nXX\nSJ Prio member: Prio\nBooking no: BBBBBBBB\nTicket no: UYXIKH-00001 CIV issuer <1174>\n\u{FFFC}\nTicket 1 of 2\n\u{FFFC}\nTuesday, 20 October 2026\n\u{FFFC}\n13:01 Kolding\n18:25 Nässjö Central\n\u{FFFC}\nTrain 306\n\u{FFFC}\nCarriage 11\n\u{FFFC}\nSeat 105\nSnälltåget, CIV <3051>\nYouth, Seat refundable, if cancelled before departure time.\n",
    "Kolding–Jönköping Central\nXX\nSJ Prio member: Prio\nBooking no: BBBBBBBB\nTicket no: 261018979314\n\u{FFFC}\nTicket 2 of 2\n\u{FFFC}\nTuesday, 20 October 2026\n\u{FFFC}\n19:20 Nässjö Central\n19:51 Jönköping Central\n\u{FFFC}\nTrain 7256\n\u{FFFC}\nNo seat reservation\nVästtrafik\nYouth, 2 class, non-refundable\nYour journey\n\u{FFFC}\nLevel boarding on the train\n",
]

private let receipt = [
    "477,00 SEK\nTotal\nSJ AB, Org.nr 556196-1599\nWebbplats www.sj.se\nDatum 18 okt 2026 kl 19:44\nBokningsnummer BBBBBBBB\nDin resa\nKolding–Nässjö Central\nSnälltåget, Kan återbetalas\n20 okt 2026 kl 13:01\nUngdom 18-19 år 427,00 SEK\nNässjö Central–Jönköping Central\nVästtrafik, Kan ej ombokas\n20 okt 2026 kl 19:20\nUngdom 18-19 år 50,00 SEK\nTotal moms 0,00 SEK\nVarav moms 0 % 0,00 SEK\nNetto 477,00 SEK\nBrutto 477,00 SEK\nBetalning\nVISA\n4054 13** **** 7615 477,00 SEK",
]

struct TicketReaderTests {
    @Test func readsASwedishTicketOneTrainPerPage() {
        let trains = TicketReader.trains(fromPages: swedishTicket)
        #expect(trains == [
            TicketTrain(operatorName: "Västtrafik", trainNumber: "7225", date: "2026-10-10", from: "Jönköping Central", to: "Nässjö Central", dep: "12:05", arr: "12:38"),
            TicketTrain(operatorName: "Snälltåget", trainNumber: "307", date: "2026-10-10", from: "Nässjö Central", to: "Kolding", dep: "13:32", arr: "18:52"),
        ])
    }

    @Test func readsAnEnglishTicket() {
        let trains = TicketReader.trains(fromPages: englishTicket)
        #expect(trains.map(\.trainNumber) == ["306", "7256"])
        #expect(trains.map(\.date) == ["2026-10-20", "2026-10-20"])
        #expect(trains[0].from == "Kolding")
        #expect(trains[0].operatorName == "Snälltåget")
        #expect(trains[1].dep == "19:20")
        #expect(trains[1].operatorName == "Västtrafik")
    }

    @Test func readsAReceiptWithNoTrainNumber() {
        let trains = TicketReader.trains(fromPages: receipt)
        #expect(trains == [
            TicketTrain(operatorName: "Snälltåget", trainNumber: nil, date: "2026-10-20", from: "Kolding", to: "Nässjö Central", dep: "13:01", arr: nil),
            TicketTrain(operatorName: "Västtrafik", trainNumber: nil, date: "2026-10-20", from: "Nässjö Central", to: "Jönköping Central", dep: "19:20", arr: nil),
        ])
    }

    @Test func somethingThatIsNotATicketGivesNothing() {
        #expect(TicketReader.trains(fromPages: ["Hello\nThis is a letter."]).isEmpty)
        #expect(TicketReader.trains(fromPages: []).isEmpty)
    }

    @Test func takesTheAttachedPDFOutOfAnEmail() {
        let payload = Data("%PDF-1.4 test".utf8)
        let eml = """
        From: SJ <noreply@ticket.sj.se>
        Subject: Tickets
        Content-Type: multipart/mixed; boundary="XYZ"

        --XYZ
        Content-Type: text/html; charset=UTF-8

        <p>Hi</p>
        --XYZ
        Content-Type: application/octet-stream; name=AAAAAAAA_1.pdf
        Content-Transfer-Encoding: base64
        Content-Disposition: attachment; filename=AAAAAAAA_1.pdf

        \(payload.base64EncodedString())
        --XYZ--
        """
        #expect(TicketReader.pdf(fromEmail: Data(eml.utf8)) == payload)
        #expect(TicketReader.pdf(fromEmail: Data("Subject: x\n\nno attachment".utf8)) == nil)
    }

    // MARK: matching

    private func result(_ number: String, from: Double, to: Double, also: [String] = []) throws -> TripResult {
        let json = """
        {"key":"k\(number)","serviceDate":"2026-10-10","trainNumber":"\(number)","operatorId":"vasttagen","category":"regional","product":"regional",
        "trainType":null,"routeName":null,
        "from":{"seq":1,"stationId":"A","name":"A","code":null,"country":"SE","tz":"Europe/Stockholm","time":\(from)},
        "to":{"seq":2,"stationId":"B","name":"B","code":null,"country":"SE","tz":"Europe/Stockholm","time":\(to)},
        "durationMin":33,"stopsBetween":0,"alsoKnownAs":[\(also.map { "\"\($0)\"" }.joined(separator: ","))]}
        """
        return try JSONDecoder().decode(TripResult.self, from: Data(json.utf8))
    }

    private func ms(_ iso: String) -> Double { (Instant.parse(iso)?.timeIntervalSince1970 ?? 0) * 1000 }

    @Test func matchesByDepartureMinuteEvenWhenTheNumberDiffers() throws {
        // 12:05 Stockholm time on 10 Oct is 10:05 UTC. The ticket says 7225; the timetable has 7205.
        let results = [
            try result("7202", from: ms("2026-10-10T09:06:00Z"), to: ms("2026-10-10T09:37:00Z")),
            try result("7205", from: ms("2026-10-10T10:05:00Z"), to: ms("2026-10-10T10:38:00Z")),
        ]
        let train = TicketTrain(operatorName: "Västtrafik", trainNumber: "7225", date: "2026-10-10", from: "A", to: "B", dep: "12:05", arr: "12:38")
        #expect(TicketReader.pick(results, for: train)?.trainNumber == "7205")
    }

    @Test func noTrainAtThatMinuteMeansNoMatch() throws {
        let results = [try result("7202", from: ms("2026-10-10T09:06:00Z"), to: ms("2026-10-10T09:37:00Z"))]
        let train = TicketTrain(operatorName: nil, trainNumber: nil, date: "2026-10-10", from: "A", to: "B", dep: "12:05", arr: nil)
        #expect(TicketReader.pick(results, for: train) == nil)
    }

    @Test func theNumberBreaksATie() throws {
        let results = [
            try result("1", from: ms("2026-10-10T10:05:00Z"), to: ms("2026-10-10T10:38:00Z")),
            try result("2", from: ms("2026-10-10T10:05:00Z"), to: ms("2026-10-10T10:38:00Z"), also: ["99"]),
        ]
        let train = TicketTrain(operatorName: nil, trainNumber: "99", date: "2026-10-10", from: "A", to: "B", dep: "12:05", arr: nil)
        #expect(TicketReader.pick(results, for: train)?.trainNumber == "2")
    }
}
