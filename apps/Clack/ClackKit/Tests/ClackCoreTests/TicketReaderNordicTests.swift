//
//  TicketReaderNordicTests.swift
//  ClackTests
//
//  The texts are what PDFKit read from real DSB and DB tickets, cut to the parts that matter, with every name, email,
//  ID card digit, order, ticket and control number replaced.
//

import Foundation
import Testing
@testable import ClackCore

/// DSB Orange with a seat ("billet" from January 2026).
private let dsbSeat = [
    "Afgang fra Kolding DSB Print Selv-billet\nBilletoplysninger\n15.jan. 06:05 Via: se rejseplanen\nBillettype DSB Orange Pladsreservation\n15.jan. 06:05 Tognr InterCityLyn 910 Ankomst til\nKøbenhavns Lufthavn 15.jan. 08:32\nKontrolnummer\n000 - O\nAfgang fra Kolding Vognnr. 63 Ankomst til\nKøbenhavns Lufthavn Pladsnr. 24 15.jan. 08:32\nAntal Pladstype\n1 Standard\nDu har valgt følgende kort som Print Selv-ID på rejsen:\nPas 0000 Navn: XX\nBestillers e-mail\nxx@example.com\nBestillingstidspunkt Billetnummer\n10.01.26 21:38 XXXXXXXX\n",
    "Din Rejseplan\nTil rejsen Kolding St.\n- CPH Lufthavn, Torsdag d. 15 januar\nStart/Stop Fra: Kolding St.\nTil: CPH Lufthavn\nKl: Afg: 06:05\nAnk: 08:32\nDato: 15.01.26\n15.01.26\nVarighed: 02:27 0\nSkift: Transportmidler:\nDetaljer\nKolding St.\nCPH Lufthavn\nAfg: 06:05\nAnk: 08:32 IC-Lyntog 910 til CPH Lufthavn\nOrdrenummer. 000000000 CVR-nummer: 25050053\n",
]

/// DSB Orange with a change at Fredericia (November 2025).
private let dsbChange = [
    "DSB Print Selv-billet\nBilletoplysninger\n06.nov. 18:01 Afgang fra København H Ankomst til\nKolding 06.nov. 20:33\nPas 0000 Navn: XX\nBestillers e-mail\nxx@example.com\n02.11.25 23:48 XXXXXXXX\n",
    "Din Rejseplan\nTil rejsen København H - Kolding St., Torsdag d. 6 november\nStart/Stop Fra: København H\nTil: Kolding St.\nKl: Afg: 18:01\nAnk: 20:33\nDato: 06.11.25\n06.11.25\nVarighed: 02:32 1\nSkift: Transportmidler:\nDetaljer\nKøbenhavn H\nFredericia St.\nFredericia St.\nKolding St.\nAfg: 18:01\nAnk: 20:02 Afg: 20:23\nAnk: 20:33 InterCity-tog 50169 til Fredericia St.\nInterCity-tog 55767 til Kolding St.\nOrdrenummer. 000000000 CVR-nummer: 25050053\n",
]

/// The 2023 layout ("Print Selv-billet" without "DSB" in its title), a regional train then an InterCity.
private let dsb2023 = [
    "Print Selv-billet\nBilletoplysninger\n18.aug. 10:14 Afgang fra Vejen Ankomst til\nOdense 18.aug. 11:23\nPas 0000 Navn: XX\n",
    "Din Rejseplan\nTil rejsen Vejen St.\n- Odense St., Fredag d. 18 august\nStart/Stop Fra: Vejen St.\nTil: Odense St.\nKl: Afg: 10:14\nAnk: 11:23\nDato: 18.08.23\n18.08.23\nVarighed: 01:09 1\nSkift: Transportmidler:\nDetaljer\nVejen St.\nFredericia St.\nFredericia St.\nOdense St.\nAfg: 10:14\nAnk: 10:46 Afg: 10:53\nAnk: 11:23 Regional-tog 53331 til Fredericia St.\nInterCity-tog 128 til Odense St.\n",
]

/// DB IC/EC ticket, Lübeck → Vejle (October 2023): three German legs, then two into Denmark.
private let db2023 = [
    "Online-Ticket\nCIV 1080\nIC/EC Fahrkarte\nGültigkeit: 15.10.2023 00:00 Uhr bis 17.10.2023 03:00 Uhr\nEinfache Fahrt Lübeck Vejle\nZugbindung IC 5764, 20:48 Uhr\nXX\nAuftragsnummer: 000000000000\nIhre Reiseverbindung und Reservierung - Einfache Fahrt am 15.10.2023\nHalt Datum Zeit Gleis Produkte Reservierung / Hinweise\nLübeck Hbf\nBad Oldesloe\n15.10.\n15.10.\nab 18:10\nan 18:27\n8\n6\nRE 8 (11429)\nBad Oldesloe\nNeumünster\n15.10.\n15.10.\nab 18:37\nan 19:27\n5\n1\nNBE RB82\n(82200)\nNeumünster\nFlensburg\n15.10.\n15.10.\nab 19:32\nan 20:40\n3\n2\nRE 7 (11178)\nFlensburg\nFredericia st\n15.10.\n15.10.\nab 20:48\nan 22:14\n1\n3\nIC 5764\nFredericia st\nVejle st\n15.10.\n15.10.\nab 22:20\nan 22:44\n4\n6\nIC 177\nWichtige Nutzungshinweise:\nTicketcode: XXXXXXXX Seite 1 / 1\n",
]

/// DB ICE ticket, Lübeck → Kolding (October 2026), with platforms like "2a" and "6b".
private let db2026 = [
    "\u{FFFC}\nCIV 1080\nOnline-Ticket\nICE Fahrkarte\nGültigkeit: 18.10.2026 00:00 Uhr bis 20.10.2026 03:00 Uhr\nZugbindung ECE 392, 20:27 Uhr am 18.10.2026\nXX\nAuftragsnummer: 000000000000\nIhre Reiseverbindung und Reservierung - Einfache Fahrt am 18.10.2026\nHalt Datum Zeit Gleis Produkte Reservierung / Hinweise\nLübeck Hbf\nKiel Hbf\n18.10.\n18.10.\nab 17:28\nan 18:56\n6\n2a\nRB84 (21074)\nKiel Hbf\nSchleswig\n18.10.\n18.10.\nab 19:03\nan 19:53\n6b\n1\nRE74 (11930)\nSchleswig\nKolding st\n18.10.\n18.10.\nab 20:27\nan 21:44\n1\n2\nECE 392\nWichtige Nutzungshinweise:\n",
]

struct TicketReaderNordicTests {
    @Test func readsADSBTicketWithItsSeat() {
        #expect(TicketReader.trains(fromPages: dsbSeat) == [
            TicketTrain(trainNumber: "910", date: "2026-01-15", from: "Kolding", to: "CPH Lufthavn", dep: "06:05", arr: "08:32", coach: "63", seat: "24", issuer: .dsb),
        ])
    }

    @Test func readsADSBTicketWithAChange() {
        #expect(TicketReader.trains(fromPages: dsbChange) == [
            TicketTrain(trainNumber: "50169", date: "2025-11-06", from: "København H", to: "Fredericia", dep: "18:01", arr: "20:02", issuer: .dsb),
            TicketTrain(trainNumber: "55767", date: "2025-11-06", from: "Fredericia", to: "Kolding", dep: "20:23", arr: "20:33", issuer: .dsb),
        ])
    }

    @Test func readsTheOlderDSBLayout() {
        let trains = TicketReader.trains(fromPages: dsb2023)
        #expect(trains.map(\.trainNumber) == ["53331", "128"])
        #expect(trains.map(\.date) == ["2023-08-18", "2023-08-18"])
        #expect(trains.map(\.from) == ["Vejen", "Fredericia"])
        #expect(trains.map(\.dep) == ["10:14", "10:53"])
        #expect(trains.allSatisfy { $0.coach == nil && $0.seat == nil })
    }

    @Test func readsEveryLegOfADBTicket() {
        let trains = TicketReader.trains(fromPages: db2023)
        #expect(trains.map(\.trainNumber) == ["11429", "82200", "11178", "5764", "177"])
        #expect(trains.map(\.from) == ["Lübeck Hbf", "Bad Oldesloe", "Neumünster", "Flensburg", "Fredericia"])
        #expect(trains.last == TicketTrain(trainNumber: "177", date: "2023-10-15", from: "Fredericia", to: "Vejle", dep: "22:20", arr: "22:44", issuer: .db))
    }

    @Test func readsADBTicketWithLetteredPlatforms() {
        let trains = TicketReader.trains(fromPages: db2026)
        #expect(trains.map(\.trainNumber) == ["21074", "11930", "392"])
        #expect(trains.map(\.dep) == ["17:28", "19:03", "20:27"])
        #expect(trains[2].to == "Kolding")
        #expect(trains.allSatisfy { $0.date == "2026-10-18" && $0.issuer == .db })
    }

    @Test func stationSuffixesAreDropped() {
        #expect(TicketReader.stationName("Kolding St.") == "Kolding")
        #expect(TicketReader.stationName("Vejle st") == "Vejle")
        #expect(TicketReader.stationName("København H") == "København H")
    }
}
