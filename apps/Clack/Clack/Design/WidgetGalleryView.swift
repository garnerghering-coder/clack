//
//  WidgetGalleryView.swift
//  Clack
//

#if DEBUG
import ClackCore
import ClackDesign
import SwiftUI

/// Debug only: the Home Screen widgets drawn at their true sizes on an iPhone 17 Pro (small 170 x 170, medium 364 x 170,
/// large 364 x 382), with the widgets' own inset rule and an outline of the rounded corner, to check that nothing is
/// cut and nothing crowds an edge. Launch with `-widgetGallery` (`-page 0` to `-page 6`, `-light` for the light theme).
/// The samples are made-up shapes for checking the layout (long train numbers and station names, platforms like "12b",
/// both languages, delays, cancelled, old data), never shown as data.
struct WidgetGalleryView: View {
    private let page = max(0, UserDefaults.standard.integer(forKey: "page"))
    private let light = CommandLine.arguments.contains("-light")

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text(verbatim: "Widgets \(page)/\(Self.pages.count - 1)").clack(.captionUpper).foregroundStyle(Ink.text3)
                ForEach(Array(Self.pages[min(page, Self.pages.count - 1)].enumerated()), id: \.offset) { _, row in
                    HStack(spacing: 12) {
                        ForEach(Array(row.enumerated()), id: \.offset) { _, item in frame(item) }
                    }
                }
            }
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Ink.surfaceRaised)
        .preferredColorScheme(light ? .light : .dark)
    }

    private func frame(_ item: Item) -> some View {
        let size = item.size.points
        return item.view
            .padding(WidgetInsets.insets(item.size))
            .frame(width: size.width, height: size.height)
            .background(item.background)
            .clipShape(RoundedRectangle(cornerRadius: WidgetInsets.cornerRadius, style: .continuous))
    }

    // MARK: samples

    struct Item {
        var size: WidgetSize
        var view: AnyView
        var background: AnyView
    }

    /// A Friday morning, so every run looks the same.
    private static let t = 1_792_732_440_000.0
    private static let m = 60_000.0
    private static let tz = "Europe/Stockholm"

    private static func leg(
        _ id: String, op: String, color: String, train: String, from: String, to: String, dep: Double, arr: Double,
        depPlatform: String?, arrPlatform: String?, depDelay: Int?, arrDelay: Int?, canceled: Bool = false,
        nextStop: String? = nil, stops: [String] = [], coach: String? = nil, seat: String? = nil
    ) -> WidgetSnapshot.Leg {
        WidgetSnapshot.Leg(
            id: id, journeyId: "j", operatorName: op, color: color, train: train, from: from, to: to, fromTz: tz, toTz: tz,
            depAt: dep, arrAt: arr, depPlatform: depPlatform, arrPlatform: arrPlatform, depDelayMin: depDelay, arrDelayMin: arrDelay,
            canceled: canceled, nextStop: nextStop, stops: stops, coach: coach, seat: seat
        )
    }

    private static let stops = [
        "Stockholm Central", "Stockholm Södra", "Flemingsberg", "Södertälje Syd", "Katrineholm Central", "Norrköping Central",
        "Linköping Central", "Mjölby", "Nässjö Central", "Göteborg Sävenäs",
    ]

    /// Before departure: a long operator name and number, a long route, platform 12b, a delay.
    private static func before(_ language: Language, stale: Bool = false) -> WidgetSnapshot {
        WidgetSnapshot(
            updatedAt: stale ? t - 95 * m : t - 2 * m, language: language,
            journey: [
                leg("a", op: "Öresundståg", color: "#8e8e8e", train: "10834", from: "Stockholm Central", to: "Göteborg Sävenäs",
                    dep: t + 95 * m, arr: t + 290 * m, depPlatform: "12b", arrPlatform: "3a", depDelay: 7, arrDelay: nil,
                    stops: stops, coach: "14", seat: "123"),
                leg("b", op: "Västtågen", color: "#e2001a", train: "3171", from: "Göteborg Sävenäs", to: "Uddevalla Central",
                    dep: t + 310 * m, arr: t + 380 * m, depPlatform: "1", arrPlatform: nil, depDelay: nil, arrDelay: nil),
            ]
        )
    }

    /// On the train: next stop, progress, a late arrival.
    private static func onTrain(_ language: Language) -> WidgetSnapshot {
        WidgetSnapshot(
            updatedAt: t - 1 * m, language: language,
            journey: [
                leg("a", op: "SJ", color: "#2c2c2c", train: "10592", from: "Stockholm Central", to: "Katrineholm Central",
                    dep: t - 30 * m, arr: t + 50 * m, depPlatform: "12b", arrPlatform: "3a", depDelay: 2, arrDelay: 18,
                    nextStop: "Södertälje Syd", stops: stops, coach: "4", seat: "23"),
            ]
        )
    }

    /// Between two trains.
    private static func changing(_ language: Language) -> WidgetSnapshot {
        WidgetSnapshot(
            updatedAt: t - 1 * m, language: language,
            journey: [
                leg("a", op: "Mälartåg", color: "#d4a000", train: "10592", from: "Upplands Väsby", to: "Stockholm Central",
                    dep: t - 40 * m, arr: t - 6 * m, depPlatform: "2", arrPlatform: "14", depDelay: 0, arrDelay: 0),
                leg("b", op: "SJ", color: "#2c2c2c", train: "529", from: "Stockholm Central", to: "Göteborg Central",
                    dep: t + 12 * m, arr: t + 200 * m, depPlatform: "16a", arrPlatform: "4", depDelay: nil, arrDelay: nil),
            ]
        )
    }

    private static func cancelled(_ language: Language) -> WidgetSnapshot {
        WidgetSnapshot(
            updatedAt: t - 1 * m, language: language,
            journey: [
                leg("a", op: "Vy", color: "#00873b", train: "2147", from: "Oslo lufthavn", to: "Lillehammer skysstasjon",
                    dep: t + 25 * m, arr: t + 140 * m, depPlatform: "4", arrPlatform: nil, depDelay: nil, arrDelay: nil, canceled: true),
            ]
        )
    }

    private static func board(_ language: Language, stale: Bool) -> WidgetSnapshot.StationBoard {
        let rows: [WidgetSnapshot.Departure] = [
            .init(id: "1", time: t + 3 * m, expected: t + 9 * m, delayMin: 6, platform: "12b", to: "Göteborg Sävenäs", train: "529", canceled: false),
            .init(id: "2", time: t + 6 * m, delayMin: 0, platform: "4", to: "Uppsala Central", train: "40", canceled: false),
            .init(id: "3", time: t + 9 * m, platform: "16a", to: "Katrineholm Central", train: "10592", canceled: true),
            .init(id: "4", time: t + 12 * m, expected: t + 34 * m, delayMin: 22, platform: "1", to: "Sundsvall Central", train: "10181", canceled: false),
            .init(id: "5", time: t + 15 * m, platform: nil, to: "Märsta", train: "2234", canceled: false),
            .init(id: "6", time: t + 18 * m, delayMin: 1, platform: "13", to: "Stockholm Arlanda Central", train: "7", canceled: false),
            .init(id: "7", time: t + 21 * m, platform: "2", to: "Västerås Central", train: "1043", canceled: false),
            .init(id: "8", time: t + 24 * m, platform: "10", to: "Linköping Central", train: "6", canceled: false),
            .init(id: "9", time: t + 27 * m, platform: "11", to: "Nynäshamn", train: "2690", canceled: false),
        ]
        return .init(id: "740000001", name: "Stockholm Central", tz: tz, updatedAt: stale ? t - 50 * m : t - 1 * m, rows: rows)
    }

    private static func passport(_ language: Language, stale: Bool = false, medal: Bool = true) -> WidgetSnapshot {
        var s = WidgetSnapshot(updatedAt: t, language: language)
        s.passport = .init(
            km: 123_456, trains: 1_234, journeys: 987, stations: 1_345, countries: 12, minutes: 50_000, onTimePct: 87,
            lateMinutes: 4_000, co2SavedKg: 12_345, co2Comparison: "car",
            nextMedal: medal ? "Around the world, twice over" : nil, nextMedalValue: 123_456, nextMedalTarget: 200_000
        )
        s.passportUpdatedAt = stale ? t - 120 * m : t - 5 * m
        s.stats = .init(
            operators: [
                .init(name: "Öresundståg", count: 123, color: "#8e8e8e"), .init(name: "SJ", count: 98, color: "#2c2c2c"),
                .init(name: "Mälartåg", count: 45, color: "#d4a000"), .init(name: "Vy", count: 12, color: "#00873b"),
                .init(name: "Västtågen", count: 7, color: "#e2001a"), .init(name: "Norrtåg", count: 3), .init(name: "Arlanda Express", count: 2),
                .init(name: "Tåg i Bergslagen", count: 1),
            ],
            trainTypes: [], stations: [
                .init(name: "Stockholm Central", count: 211), .init(name: "Göteborg Sävenäs", count: 40), .init(name: "Lillehammer skysstasjon", count: 5),
            ], countries: []
        )
        s.year = .init(
            year: 2026, km: 23_456, trains: 345, topRoute: "Stockholm Central → Göteborg Sävenäs", topRouteCount: 24,
            busiestMonth: "2026-09", busiestMonthCount: 41,
            routes: [[[59.33, 18.06], [58.75, 17.0], [58.0, 15.0], [57.71, 11.97]], [[59.33, 18.06], [60.67, 17.14], [62.39, 17.31]]]
        )
        return s
    }

    private static func journey(_ s: WidgetSnapshot, _ size: WidgetSize) -> Item {
        let color = WidgetTimeline.shown(s, at: t)?.leg?.color
        return Item(size: size, view: AnyView(NextJourneyWidgetView(snapshot: s, date: wDate(t), size: size)),
                    background: AnyView(TintedBackground(hex: color)))
    }

    private static func departures(_ language: Language, _ size: WidgetSize, stale: Bool = false) -> Item {
        Item(size: size, view: AnyView(DeparturesWidgetView(
            date: wDate(t), size: size, stationId: "740000001", stationName: nil, board: board(language, stale: stale), language: language, clock: .h24
        )), background: AnyView(Ink.bg))
    }

    private static func passportCard(_ s: WidgetSnapshot, _ size: WidgetSize) -> Item {
        Item(size: size, view: AnyView(PassportWidgetView(snapshot: s, date: wDate(t), size: size)), background: AnyView(FoilBackground()))
    }

    private static func stats(_ s: WidgetSnapshot, _ size: WidgetSize, page: StatsPage) -> Item {
        Item(size: size, view: AnyView(StatsWidgetView(snapshot: s, date: wDate(t), size: size, page: page) {
            StatsWidgetView<EmptyView>.buttonFace
        }), background: AnyView(Ink.bg))
    }

    private static func year(_ s: WidgetSnapshot) -> Item {
        Item(size: .large, view: AnyView(YearWidgetView(snapshot: s, date: wDate(t))), background: AnyView(Ink.bg))
    }

    static let pages: [[[Item]]] = [
        [
            [journey(before(.en), .small), journey(before(.sv, stale: true), .small)],
            [journey(onTrain(.en), .small), journey(onTrain(.sv), .small)],
            [journey(changing(.en), .small), journey(cancelled(.sv), .small)],
            [journey(before(.sv, stale: true), .medium)],
        ],
        [
            [journey(before(.en), .medium)], [journey(onTrain(.sv), .medium)], [journey(changing(.en), .medium)],
            [journey(cancelled(.sv), .medium)],
        ],
        [[journey(before(.sv, stale: true), .large)], [journey(onTrain(.en), .large)]],
        [[departures(.en, .medium)], [departures(.sv, .medium, stale: true)], [departures(.en, .large)]],
        [
            [passportCard(passport(.en), .small), passportCard(passport(.sv, stale: true), .small)],
            [passportCard(passport(.sv, stale: true), .medium)], [passportCard(passport(.en), .large)],
        ],
        [
            [stats(passport(.en), .medium, page: .operators)], [stats(passport(.sv, stale: true), .medium, page: .stations)],
            [stats(passport(.sv, stale: true), .large, page: .operators)],
        ],
        [[year(passport(.en))], [year(passport(.sv, stale: true))]],
    ]
}
#endif
