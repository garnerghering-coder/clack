//
//  WidgetShared.swift
//  ClackWidgets
//
//  What the Home Screen widgets share: the board colours, words in the phone's language, the data they read (the app's snapshot, or
//  sample data while there is no App Group) and the plain-logic of "where is the journey now".
//

import SwiftUI
import WidgetKit

enum WB {
    static let bg = Color(red: 0x0A / 255, green: 0x0A / 255, blue: 0x0A / 255)
    static let tile = Color(red: 0x1A / 255, green: 0x1A / 255, blue: 0x1A / 255)
    static let text = Color.white
    static let text2 = Color(red: 0xA3 / 255, green: 0xA3 / 255, blue: 0xA3 / 255)
    static let accent = Color(red: 0xF8 / 255, green: 0xD6 / 255, blue: 0x4A / 255)
    static let onTime = Color(red: 0x3D / 255, green: 0xDC / 255, blue: 0x84 / 255)
    static let late = Color(red: 0xFF / 255, green: 0x95 / 255, blue: 0x00 / 255)
    static let cancelled = Color(red: 0xFF / 255, green: 0x45 / 255, blue: 0x3A / 255)
    static let ink = Color(red: 0x1A / 255, green: 0x15 / 255, blue: 0x00 / 255)

    static func inter(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font { .custom("InterVariable", size: size).weight(weight) }
    static func digits(_ size: CGFloat) -> Font { .custom("SpaceGrotesk-Bold", size: size) }
}

extension Color {
    init?(hex: String?) {
        guard let hex, hex.hasPrefix("#"), hex.count == 7, let v = UInt32(hex.dropFirst(), radix: 16) else { return nil }
        self.init(red: Double((v >> 16) & 0xFF) / 255, green: Double((v >> 8) & 0xFF) / 255, blue: Double(v & 0xFF) / 255)
    }
}

/// Words in the phone's language (the extension can't see the app's language setting).
enum WW {
    static var swedish: Bool { Locale.current.language.languageCode?.identifier == "sv" }
    static func t(_ en: String, _ sv: String) -> String { swedish ? sv : en }
    static var sample: String { t("SAMPLE", "EXEMPEL") }
    static var noJourney: String { t("No journey coming up", "Ingen resa på gång") }
    static var noJourneyHint: String { t("Add a train in Clack", "Lägg till ett tåg i Clack") }
    static var cancelled: String { t("Cancelled", "Inställt") }
    static var onTime: String { t("On time", "I tid") }
    static var onItsWay: String { t("On its way", "På väg") }
    static var boarding: String { t("Boarding", "Påstigning") }
    static var arrives: String { t("Arrives", "Framme") }
    static var departs: String { t("Departs", "Avgår") }
    static var next: String { t("Next", "Nästa") }
    static var change: String { t("Change trains", "Byte") }
    static var stops: String { t("Stops", "Stopp") }
    static func platform(_ p: String) -> String { t("Platform \(p)", "Spår \(p)") }
    static func late(_ n: Int) -> String { t("\(n) min late", "\(n) min försenat") }
    static func spare(_ n: Int) -> String { t("\(n) min to change", "\(n) min att byta") }
    static var km: String { t("km", "km") }
    static var trains: String { t("trains", "tåg") }
    static var stationsWord: String { t("stations", "stationer") }
    static var countriesWord: String { t("countries", "länder") }
    static var journeysWord: String { t("journeys", "resor") }
    static var onTimeRecord: String { t("On time", "I tid") }
    static var co2Saved: String { t("CO₂ saved", "CO₂ sparat") }
    static var nextMedal: String { t("Next medal", "Nästa medalj") }
    static var noBoard: String { t("Pick a station in Clack", "Välj en station i Clack") }
    static var noData: String { t("Open Clack to fill this in", "Öppna Clack för att fylla i detta") }
    static var operators: String { t("Operators", "Operatörer") }
    static var trainTypes: String { t("Train types", "Tågtyper") }
    static var topStations: String { t("Most visited stations", "Mest besökta stationer") }
    static var countries: String { t("Countries", "Länder") }
    static var topRoute: String { t("Top route", "Vanligaste sträckan") }
    static var busiestMonth: String { t("Busiest month", "Mest aktiva månad") }
    static var yearInRail: String { t("Year in rail", "Året på räls") }
}

// MARK: time

func wDate(_ ms: Double) -> Date { Date(timeIntervalSince1970: ms / 1000) }

func wTime(_ ms: Double, tz: String) -> String {
    let f = DateFormatter()
    f.dateFormat = "HH:mm"
    f.timeZone = TimeZone(identifier: tz) ?? .current
    return f.string(from: wDate(ms))
}

// MARK: the data

struct WidgetContent {
    var snapshot: WidgetSnapshot
    /// True when this is sample data (no App Group or the app hasn't written yet).
    var isSample: Bool

    static func current(now: Date = .now) -> WidgetContent {
        if let real = WidgetSnapshot.load() { return WidgetContent(snapshot: real, isSample: false) }
        return WidgetContent(snapshot: SampleData.snapshot(now: now), isSample: true)
    }
}

/// Invented, labelled SAMPLE on the widgets. Real names and numbers are never made up for the real thing: the real thing reads the app's snapshot.
enum SampleData {
    static func snapshot(now: Date) -> WidgetSnapshot {
        let t = now.timeIntervalSince1970 * 1000
        let m = 60_000.0
        var s = WidgetSnapshot(updatedAt: t)
        s.journey = [
            .init(id: "s1", journeyId: "sj", operatorName: "SJ", color: "#0F4C81", train: "529", from: "Stockholm C", to: "Göteborg C",
                  fromTz: "Europe/Stockholm", toTz: "Europe/Stockholm", depAt: t + 40 * m, arrAt: t + 200 * m, depPlatform: "7", arrPlatform: "4",
                  delayMin: 6, canceled: false, status: "scheduled", progress: nil, nextStop: "Katrineholm", nextStopAt: t + 90 * m,
                  stops: ["Stockholm C", "Södertälje syd", "Katrineholm", "Skövde C", "Göteborg C"]),
            .init(id: "s2", journeyId: "sj", operatorName: "Västtrafik", color: "#009EE0", train: "7225", from: "Göteborg C", to: "Alingsås",
                  fromTz: "Europe/Stockholm", toTz: "Europe/Stockholm", depAt: t + 215 * m, arrAt: t + 250 * m, depPlatform: "12", arrPlatform: "2",
                  delayMin: nil, canceled: false, status: "scheduled", progress: nil, nextStop: nil, nextStopAt: nil,
                  stops: ["Göteborg C", "Partille", "Lerum", "Alingsås"]),
        ]
        s.passport = .init(km: 18_420, trains: 212, journeys: 140, stations: 96, countries: 4, minutes: 14_300, year: nil, onTimePct: 78, lateMinutes: 640,
                           co2SavedKg: 2_150, co2Comparison: "car", nextMedal: "20 000 km", nextMedalValue: 18_420, nextMedalTarget: 20_000)
        s.stats = .init(
            operators: [.init(name: "SJ", count: 88, color: "#0F4C81"), .init(name: "Västtrafik", count: 40, color: "#009EE0"),
                        .init(name: "Vy", count: 22, color: "#D2232A"), .init(name: "Öresundståg", count: 14, color: "#E5A100")],
            trainTypes: [.init(name: "Regional", count: 90, color: nil), .init(name: "Fast train", count: 70, color: nil), .init(name: "Night train", count: 8, color: nil)],
            stations: [.init(name: "Stockholm C", count: 41, color: nil), .init(name: "Göteborg C", count: 30, color: nil), .init(name: "Nässjö C", count: 18, color: nil)],
            countries: [.init(name: "Sweden", count: 180, color: nil), .init(name: "Norway", count: 20, color: nil), .init(name: "Denmark", count: 12, color: nil)]
        )
        s.year = .init(year: Calendar.current.component(.year, from: now), km: 6_200, trains: 74, topRoute: "Stockholm C – Göteborg C", topRouteCount: 11,
                       busiestMonth: "March", busiestMonthCount: 14,
                       routes: [[[59.33, 18.06], [58.6, 16.2], [58.1, 14.3], [57.7, 11.97]], [[57.7, 11.97], [58.28, 12.28], [58.5, 13.1]],
                                [[59.33, 18.06], [59.6, 17.0], [59.86, 17.64]], [[57.7, 11.97], [59.9, 10.75]]])
        let towns = ["Göteborg C", "Malmö C", "Uppsala C", "Karlstad C"]
        var rows: [WidgetSnapshot.Departure] = []
        for i in 0..<8 {
            let when: Double = t + Double(6 + i * 11) * m
            rows.append(WidgetSnapshot.Departure(
                id: "d\(i)", time: when, delayMin: i == 2 ? 4 : nil, platform: String(7 + i % 4), to: towns[i % 4],
                train: String(500 + i * 13), canceled: i == 5
            ))
        }
        s.boards = [WidgetSnapshot.StationBoard(id: "s", name: "Stockholm C", rows: rows)]
        return s
    }
}

// MARK: shared views

/// A time or number as a small board: one dark tile per character (static; a widget can't animate).
struct FlapText: View {
    var text: String
    var size: CGFloat = 20
    var color: Color = WB.text
    var body: some View {
        HStack(spacing: size * 0.08) {
            ForEach(Array(text.enumerated()), id: \.offset) { _, ch in
                Text(String(ch))
                    .font(WB.digits(size)).foregroundStyle(color).monospacedDigit()
                    .frame(width: ch == ":" ? size * 0.38 : size * 0.68, height: size * 1.25)
                    .background(ch == ":" ? Color.clear : WB.tile, in: RoundedRectangle(cornerRadius: 3))
                    .overlay(alignment: .center) {
                        if ch != ":" { Rectangle().fill(Color.black.opacity(0.55)).frame(height: 1) }
                    }
            }
        }
    }
}

struct SampleTag: View {
    var onLight = false
    var body: some View {
        Text(WW.sample).font(WB.inter(8, .heavy)).tracking(0.8).foregroundStyle(onLight ? WB.ink.opacity(0.6) : WB.text2)
    }
}

struct EmptyWidget: View {
    var title: String
    var hint: String
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Image(systemName: "tram.fill").foregroundStyle(WB.accent)
            Text(title).font(WB.inter(15, .bold)).foregroundStyle(WB.text)
            Text(hint).font(WB.inter(12)).foregroundStyle(WB.text2)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}
