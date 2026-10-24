//
//  WidgetData.swift
//  Clack
//
//  Fetches what the widgets show and keeps it in the App Group as the cache (owner, 2026-10-24). The widget extension calls
//  `load` from its timeline providers; the app builds the same snapshot from what it has already fetched (`WidgetFeed`).
//  On a failure, or after the timeout, the cached snapshot is returned unchanged: never invented data.
//

import Foundation

/// The widgets' kinds, for `WidgetCenter.reloadTimelines(ofKind:)`.
public nonisolated enum WidgetKinds {
    public static let nextJourney = "NextJourney"
    public static let passport = "Passport"
    public static let departures = "Departures"
    public static let year = "YearInRail"
    public static let stats = "Stats"
}

/// Where a tap on each widget goes (the app's `clack://` routes).
public nonisolated enum WidgetLinks {
    public static func trip(_ legId: String) -> URL? { URL(string: "clack://trip/\(encode(legId))") }
    public static let passport = URL(string: "clack://passport")
    public static func board(_ stationId: String) -> URL? { URL(string: "clack://board/\(encode(stationId))") }

    private static func encode(_ id: String) -> String {
        id.addingPercentEncoding(withAllowedCharacters: .alphanumerics.union(CharacterSet(charactersIn: "-._~"))) ?? id
    }
}

public nonisolated enum WidgetData {
    /// The parts of the snapshot a widget needs.
    public struct Parts: OptionSet, Sendable {
        public let rawValue: Int
        public init(rawValue: Int) { self.rawValue = rawValue }
        /// The featured journey and the next one.
        public static let journey = Parts(rawValue: 1)
        /// The Passport, the stats and the year in rail.
        public static let passport = Parts(rawValue: 2)
        /// Station boards (the ids are passed separately).
        public static let boards = Parts(rawValue: 4)
    }

    /// How many rows a board keeps: enough for 30 minutes of a large widget dropping the ones that leave.
    public static let boardRows = 24

    // MARK: fetching

    /// A client for this phone's id, with no kept copies (an answer from the cache must not pass for a fresh one); nil when
    /// the app hasn't made an id yet.
    public static func client() -> APIClient? { Identity.existing().map { APIClient(userID: $0, cache: nil) } }

    /// Fetches the parts asked for, writes them into the cache and returns the whole snapshot. Gives up after `timeout`
    /// seconds and returns the cache. Parts younger than `maxAge` are not fetched again (the app may just have written
    /// them). With no phone id (the app hasn't been opened yet) nothing is fetched.
    public static func load(
        _ parts: Parts, boards: [String] = [], timeout: Double = 8, maxAge: Double = 0,
        now: Double = Date.now.timeIntervalSince1970 * 1000
    ) async -> WidgetSnapshot {
        let cached = WidgetSnapshot.load() ?? WidgetSnapshot()
        guard let client = client() else { return cached }
        var wanted = parts
        if now - cached.updatedAt < maxAge { wanted.remove(.journey) }
        if now - cached.passportUpdatedAt < maxAge { wanted.remove(.passport) }
        let stale = boards.filter { id in !(cached.boards.first { $0.id == id }.map { now - $0.updatedAt < maxAge } ?? false) }
        if stale.isEmpty { wanted.remove(.boards) }
        if wanted.isEmpty { return cached }
        let ask = wanted
        let fresh = await within(timeout) { await fetch(ask, boards: stale, base: cached, client: client, now: now) }
        guard let fresh else { return cached }
        return await WidgetStore.shared.merge(fresh.snapshot, parts: fresh.done, boards: fresh.boards)
    }

    struct Fetched: Sendable {
        var snapshot: WidgetSnapshot
        /// The parts that were fetched; the others are as they were.
        var done: Parts
        /// The boards that were fetched.
        var boards: [String]
    }

    static func fetch(_ parts: Parts, boards ids: [String], base: WidgetSnapshot, client: APIClient, now: Double) async -> Fetched {
        var s = base
        var done: Parts = []
        var boards: [String] = []
        let settings = try? await client.settings()
        if let settings {
            s.language = settings.language
            s.clock = settings.clock
            s.distanceUnit = settings.distanceUnit
        }
        if parts.contains(.journey), let legs = try? await client.legs() {
            let details = await self.details(detailIds(legs, now: now), client: client)
            (s.journey, s.nextJourney) = journeys(legs, details: details, now: now)
            s.updatedAt = now
            done.insert(.journey)
        }
        if parts.contains(.passport), let settings,
           let all = try? await client.passport(year: nil, commuter: settings.includeCommuter, comparison: settings.co2Comparison) {
            let year = Calendar.current.component(.year, from: Date(timeIntervalSince1970: now / 1000))
            let yearly = try? await client.passport(year: year, commuter: settings.includeCommuter, comparison: settings.co2Comparison)
            let language = settings.language
            let (passport, stats) = await MainActor.run {
                let l10n = L10n(language: language)
                return (
                    passportBits(all, year: nil) { l10n.milestoneLabel($0, language: language) },
                    statsBits(all) { l10n.countryName($0) }
                )
            }
            s.passport = passport
            s.stats = stats
            s.year = yearly.map { yearBits($0, year: year) }
            s.passportUpdatedAt = now
            done.insert(.passport)
        }
        if parts.contains(.boards) {
            for id in ids {
                guard let board = await self.board(id, cached: base.boards.first { $0.id == id }, client: client, now: now) else { continue }
                s.boards.removeAll { $0.id == id }
                s.boards.append(board)
                boards.append(id)
            }
            if !boards.isEmpty { done.insert(.boards) }
        }
        return Fetched(snapshot: s, done: done, boards: boards)
    }

    private static func details(_ ids: [String], client: APIClient) async -> [String: LegDetail] {
        await withTaskGroup(of: LegDetail?.self) { group in
            for id in ids { group.addTask { try? await client.leg(id) } }
            var out: [String: LegDetail] = [:]
            for await detail in group { if let detail { out[detail.id] = detail } }
            return out
        }
    }

    /// One station's departures, with its name and time zone (asked once, then kept with the board).
    public static func board(_ id: String, cached: WidgetSnapshot.StationBoard?, client: APIClient, now: Double) async -> WidgetSnapshot.StationBoard? {
        guard let board = try? await client.board(id, arrivals: false) else { return nil }
        var name = cached?.name
        var tz = cached?.tz
        if tz == nil || name == nil, let info = try? await client.station(id) {
            name = info.name
            tz = info.tz
        }
        return WidgetSnapshot.StationBoard(id: id, name: name ?? id, tz: tz, updatedAt: now, rows: departures(board, now: now))
    }

    /// Runs `work`, or gives up after `seconds` (nil).
    static func within<T: Sendable>(_ seconds: Double, _ work: @escaping @Sendable () async -> T) async -> T? {
        await withTaskGroup(of: T?.self) { group in
            group.addTask { await work() }
            group.addTask {
                try? await Task.sleep(for: .seconds(seconds))
                return nil
            }
            let first = await group.next() ?? nil
            group.cancelAll()
            return first
        }
    }

    // MARK: building the snapshot (also used by the app)

    /// The legs whose details are fetched: the featured one and the next leg of its journey (for their stops).
    public static func detailIds(_ legs: [Leg], now: Double) -> [String] {
        let (upcoming, past) = TripsLogic.partition(legs, now: now)
        guard let hero = TripsLogic.hero(upcoming: upcoming, past: past, now: now)?.leg else { return [] }
        return [hero.id] + (TripsLogic.nextInJourney(legs, after: hero).map { [$0.id] } ?? [])
    }

    private static func journeyKey(_ leg: Leg) -> String { leg.journeyId ?? leg.id }

    /// Every leg of the journey `leg` belongs to, in travel order (cancelled ones too: the widget says so).
    private static func journeyLegs(of leg: Leg, in legs: [Leg]) -> [Leg] {
        guard leg.journeyId != nil else { return [leg] }
        return legs.filter { journeyKey($0) == journeyKey(leg) }.sorted { ($0.schedDep?.ms ?? 0) < ($1.schedDep?.ms ?? 0) }
    }

    /// The featured journey (the Trips tab's hero: running now, else the earliest upcoming, else arrived in the last 6
    /// hours) and the next upcoming journey after it, for when it ends.
    public static func journeys(_ legs: [Leg], details: [String: LegDetail], now: Double) -> (hero: [WidgetSnapshot.Leg], next: [WidgetSnapshot.Leg]) {
        let (upcoming, past) = TripsLogic.partition(legs, now: now)
        guard let hero = TripsLogic.hero(upcoming: upcoming, past: past, now: now)?.leg else { return ([], []) }
        let heroLegs = journeyLegs(of: hero, in: legs)
        let after = upcoming.first { journeyKey($0) != journeyKey(hero) && !$0.canceled }
        let nextLegs = after.map { journeyLegs(of: $0, in: legs) } ?? []
        return (heroLegs.compactMap { leg($0, detail: details[$0.id]) }, nextLegs.compactMap { leg($0, detail: details[$0.id]) })
    }

    /// A leg as the widgets keep it; nil without both times.
    public static func leg(_ l: Leg, detail: LegDetail?) -> WidgetSnapshot.Leg? {
        let times = TripsLogic.expected(l)
        guard let dep = times.dep, let arr = times.arr else { return nil }
        let ridden = detail?.stops.filter { $0.role.isRidden }.map(\.name) ?? []
        let nextStop = l.live?.nextStopId.flatMap { id in detail?.stops.first { $0.stationId == id }?.name }
        return WidgetSnapshot.Leg(
            id: l.id, journeyId: l.journeyId, operatorName: l.operator?.name, color: l.operator?.brandColor, train: l.trainNumber,
            from: l.origin?.name ?? "", to: l.destination?.name ?? "",
            fromTz: l.origin?.tz ?? TripsLogic.tz(l), toTz: l.destination?.tz ?? TripsLogic.tz(l),
            depAt: dep, arrAt: arr, depPlatform: l.depPlatform, arrPlatform: l.arrPlatform,
            depDelayMin: l.depDelayMin, arrDelayMin: l.arrDelayMin ?? l.live?.arrivalDelayMin,
            canceled: l.canceled, status: l.live?.status.rawValue, progress: l.live?.progress,
            nextStop: nextStop, nextStopAt: nextStop == nil ? nil : l.live?.eta?.ms, stops: ridden
        )
    }

    /// The rows still to leave, in board order, at most `boardRows`.
    public static func departures(_ board: Board, now: Double) -> [WidgetSnapshot.Departure] {
        let rows = board.rows.filter { !$0.done && ($0.estimated ?? $0.advertised) > now - 60_000 }.sorted { $0.advertised < $1.advertised }
        return rows.prefix(boardRows).map { row in
            WidgetSnapshot.Departure(
                id: row.id, time: row.advertised, expected: row.estimated, delayMin: row.delayMin, platform: row.platform,
                to: row.endpoints.last ?? row.via.last ?? "", train: row.trainNumber, canceled: row.canceled
            )
        }
    }

    public static func passportBits(_ p: Passport, year: Int?, medal: (Milestone) -> String) -> WidgetSnapshot.PassportBits {
        let next = p.milestones.next.first
        return WidgetSnapshot.PassportBits(
            km: p.totals.distanceM / 1000, trains: p.totals.trains, journeys: p.totals.journeys, stations: p.totals.stations,
            countries: p.totals.countries, minutes: p.totals.minutes, year: year, onTimePct: p.delays.onTimePct,
            lateMinutes: p.delays.totalLateMin, co2SavedKg: p.co2.savedKg, co2Comparison: p.co2.comparison,
            nextMedal: next.map(medal), nextMedalValue: next?.value, nextMedalTarget: next?.target
        )
    }

    public static func statsBits(_ p: Passport, country: (String) -> String) -> WidgetSnapshot.StatsBits {
        WidgetSnapshot.StatsBits(
            operators: p.operators.prefix(12).map { row in
                let op = p.refs.operators[row.key]
                return WidgetSnapshot.Row(name: op?.name ?? row.key, count: row.count, color: op?.brandColor)
            },
            trainTypes: p.trainTypes.prefix(12).map { WidgetSnapshot.Row(name: p.refs.trainTypes[$0.key]?.name ?? $0.key, count: $0.count) },
            stations: p.stations.sorted { $0.count > $1.count }.prefix(12).map { WidgetSnapshot.Row(name: $0.name, count: $0.count) },
            countries: p.countries.prefix(12).map { WidgetSnapshot.Row(name: country($0.code), count: $0.legs) }
        )
    }

    public static func yearBits(_ p: Passport, year: Int) -> WidgetSnapshot.YearBits {
        // Every ride as a line with at most 40 points: enough to draw, small enough for a widget file.
        let routes: [[[Double]]] = p.map.prefix(80).compactMap { route in
            let points: [[Double]]
            if let g = route.geometry {
                let all = Polyline.decode(g)
                let step = max(1, all.count / 40)
                points = stride(from: 0, to: all.count, by: step).map { [all[$0].lat, all[$0].lon] } + (all.last.map { [[$0.lat, $0.lon]] } ?? [])
            } else {
                points = route.stops
            }
            return points.count > 1 ? points : nil
        }
        return WidgetSnapshot.YearBits(
            year: year, km: p.totals.distanceM / 1000, trains: p.totals.trains, topRoute: p.flavor.topRoute?.route,
            topRouteCount: p.flavor.topRoute?.count ?? 0, busiestMonth: p.flavor.busiestMonth?.month,
            busiestMonthCount: p.flavor.busiestMonth?.count ?? 0, routes: routes
        )
    }
}

/// Writes the parts one load fetched into the latest file, so two widgets loading at once don't undo each other.
actor WidgetStore {
    static let shared = WidgetStore()

    func merge(_ fresh: WidgetSnapshot, parts: WidgetData.Parts, boards: [String]) -> WidgetSnapshot {
        var s = WidgetSnapshot.load() ?? fresh
        s.language = fresh.language
        s.clock = fresh.clock
        s.distanceUnit = fresh.distanceUnit
        if parts.contains(.journey) {
            s.journey = fresh.journey
            s.nextJourney = fresh.nextJourney
            s.updatedAt = fresh.updatedAt
        }
        if parts.contains(.passport) {
            s.passport = fresh.passport
            s.stats = fresh.stats
            s.year = fresh.year
            s.passportUpdatedAt = fresh.passportUpdatedAt
        }
        for id in boards {
            guard let board = fresh.boards.first(where: { $0.id == id }) else { continue }
            s.boards.removeAll { $0.id == id }
            s.boards.append(board)
        }
        // The stations asked for most recently.
        if s.boards.count > 8 { s.boards.removeFirst(s.boards.count - 8) }
        s.save()
        return s
    }
}
