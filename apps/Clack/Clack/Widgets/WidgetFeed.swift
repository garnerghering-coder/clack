//
//  WidgetFeed.swift
//  Clack
//

import Foundation
import WidgetKit

/// Builds the snapshot the widgets read (`WidgetSnapshot`) from what the app has: the next journey, the Passport, the stats and the
/// favourite stations' boards. Runs after the legs refresh, at most every 5 minutes. With no App Group nothing is written.
@MainActor
enum WidgetFeed {
    private static var lastRun: Double = 0

    static func refresh(legs: [Leg], details: [String: LegDetail], app: AppModel) async {
        let now = Date.now.timeIntervalSince1970 * 1000
        guard now - lastRun > 5 * 60_000, WidgetSnapshot.containerURL != nil else { return }
        lastRun = now
        var snapshot = WidgetSnapshot(updatedAt: now)
        snapshot.journey = journey(legs, details: details, now: now)

        let client = app.client
        let settings = app.settings
        if let all = try? await client.passport(year: nil, commuter: settings.includeCommuter, comparison: settings.co2Comparison) {
            snapshot.passport = passportBits(all, year: nil, app: app)
            snapshot.stats = stats(all, app: app)
            if let thisYear = Calendar.current.dateComponents([.year], from: .now).year,
               let yearly = try? await client.passport(year: thisYear, commuter: settings.includeCommuter, comparison: settings.co2Comparison) {
                snapshot.year = yearBits(yearly, year: thisYear)
            }
        }
        snapshot.boards = await boards(client: client, now: now)
        if snapshot.save() { WidgetCenter.shared.reloadAllTimelines() }
    }

    // MARK: the next journey

    private static func leg(_ l: Leg, detail: LegDetail?) -> WidgetSnapshot.Leg? {
        let times = TripsLogic.expected(l)
        guard let dep = times.dep, let arr = times.arr else { return nil }
        let ridden = detail?.stops.filter { $0.role.isRidden }.map(\.name) ?? []
        return WidgetSnapshot.Leg(
            id: l.id, journeyId: l.journeyId, operatorName: l.operator?.name, color: l.operator?.brandColor, train: l.trainNumber,
            from: l.origin?.name ?? "", to: l.destination?.name ?? "", fromTz: l.origin?.tz ?? "Europe/Stockholm", toTz: l.destination?.tz ?? "Europe/Stockholm",
            depAt: dep, arrAt: arr, depPlatform: l.depPlatform, arrPlatform: l.arrPlatform, delayMin: l.arrDelayMin ?? l.live?.arrivalDelayMin,
            canceled: l.canceled, status: l.live?.status.rawValue, progress: l.live?.progress,
            nextStop: nil, nextStopAt: l.live?.eta?.ms, stops: ridden
        )
    }

    private static func journey(_ legs: [Leg], details: [String: LegDetail], now: Double) -> [WidgetSnapshot.Leg] {
        let (upcoming, past) = TripsLogic.partition(legs, now: now)
        guard let hero = TripsLogic.hero(upcoming: upcoming, past: past, now: now)?.leg else { return [] }
        let same = legs.filter { ($0.journeyId ?? $0.id) == (hero.journeyId ?? hero.id) && !$0.canceled || $0.id == hero.id }
            .sorted { ($0.schedDep?.ms ?? 0) < ($1.schedDep?.ms ?? 0) }
        return same.compactMap { leg($0, detail: details[$0.id]) }.filter { $0.arrAt > now - 3_600_000 }
    }

    // MARK: Passport and stats

    private static func passportBits(_ p: Passport, year: Int?, app: AppModel) -> WidgetSnapshot.PassportBits {
        let next = p.milestones.next.first
        return WidgetSnapshot.PassportBits(
            km: p.totals.distanceM / 1000, trains: p.totals.trains, journeys: p.totals.journeys, stations: p.totals.stations,
            countries: p.totals.countries, minutes: p.totals.minutes, year: year, onTimePct: p.delays.onTimePct,
            lateMinutes: p.delays.totalLateMin, co2SavedKg: p.co2.savedKg, co2Comparison: p.co2.comparison,
            nextMedal: next.map { app.l10n.milestoneLabel($0, language: app.settings.language) },
            nextMedalValue: next?.value, nextMedalTarget: next?.target
        )
    }

    private static func stats(_ p: Passport, app: AppModel) -> WidgetSnapshot.StatsBits {
        func name(_ code: String) -> String {
            let key = "countries.\(code)"
            let text = app.l10n.t(key)
            return text == key ? code : text
        }
        return WidgetSnapshot.StatsBits(
            operators: p.operators.prefix(12).map { row in
                let op = p.refs.operators[row.key]
                return WidgetSnapshot.Row(name: op?.name ?? row.key, count: row.count, color: op?.brandColor)
            },
            trainTypes: p.trainTypes.prefix(12).map { WidgetSnapshot.Row(name: p.refs.trainTypes[$0.key]?.name ?? $0.key, count: $0.count, color: nil) },
            stations: p.stations.sorted { $0.count > $1.count }.prefix(12).map { WidgetSnapshot.Row(name: $0.name, count: $0.count, color: nil) },
            countries: p.countries.prefix(12).map { WidgetSnapshot.Row(name: name($0.code), count: $0.legs, color: nil) }
        )
    }

    private static func yearBits(_ p: Passport, year: Int) -> WidgetSnapshot.YearBits {
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
            year: year, km: p.totals.distanceM / 1000, trains: p.totals.trains, topRoute: p.flavor.topRoute?.route, topRouteCount: p.flavor.topRoute?.count ?? 0,
            busiestMonth: p.flavor.busiestMonth?.month, busiestMonthCount: p.flavor.busiestMonth?.count ?? 0, routes: routes
        )
    }

    // MARK: favourite stations

    private static func boards(client: APIClient, now: Double) async -> [WidgetSnapshot.StationBoard] {
        guard let favourites = try? await client.favoriteStations() else { return [] }
        var out: [WidgetSnapshot.StationBoard] = []
        for station in favourites.prefix(3) {
            guard let board = try? await client.board(station.id, arrivals: false) else { continue }
            let rows = board.rows.filter { !$0.done && ($0.estimated ?? $0.advertised) > now - 5 * 60_000 }
                .sorted { $0.advertised < $1.advertised }.prefix(8).map { row in
                    WidgetSnapshot.Departure(
                        id: row.id, time: row.estimated ?? row.advertised, delayMin: row.delayMin, platform: row.platform,
                        to: row.endpoints.last ?? row.via.last ?? "", train: row.trainNumber, canceled: row.canceled
                    )
                }
            out.append(WidgetSnapshot.StationBoard(id: station.id, name: station.name, rows: Array(rows)))
        }
        return out
    }
}
