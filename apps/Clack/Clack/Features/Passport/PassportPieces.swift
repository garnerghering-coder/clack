//
//  PassportPieces.swift
//  Clack
//

import ClackCore
import ClackDesign
import SwiftUI

/// A record or a statistic as a tile; with a `legId` it opens that trip.
struct RecordTile: View {
    let label: String
    let value: String
    let sub: String?
    let legId: String?

    var body: some View {
        let body = Tile(label: label, value: value, sub: sub)
        if let legId { NavigationLink(value: AppRoute.trip(legId)) { body }.buttonStyle(.plain) } else { body }
    }
}

/// The records (DESIGN §8.5): longest trip, longest time, biggest delay, most-ridden route, busiest station, earliest
/// departure and latest arrival, each a tile that opens its trip where there is one.
struct RecordsGrid: View {
    @Environment(AppModel.self) private var app
    @Environment(L10n.self) private var l10n
    let data: Passport

    var body: some View {
        let r = data.records
        let unit = app.settings.distanceUnit
        let lang = app.settings.language
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12, alignment: .top)], spacing: 12) {
            if let leg = r.longestDistance {
                RecordTile(label: l10n.t("passport.longestTrip"), value: Format.distance(leg.distanceM, unit: unit, language: lang), sub: "\(leg.from) → \(leg.to)", legId: leg.legId)
            }
            if let leg = r.longestDuration {
                RecordTile(label: l10n.t("passport.longestTime"), value: Format.duration(leg.minutes), sub: "\(leg.from) → \(leg.to)", legId: leg.legId)
            }
            if let leg = r.biggestDelay {
                RecordTile(label: l10n.t("passport.biggestDelay"), value: l10n.t("passport.minutesLate", count: leg.delayMin ?? 0), sub: "\(leg.from) → \(leg.to)", legId: leg.legId)
            }
            if let route = r.mostRiddenRoute {
                RecordTile(label: l10n.t("passport.mostRidden"), value: route.route, sub: l10n.t("passport.timesCount", count: route.count), legId: nil)
            }
            if let station = r.busiestStation {
                RecordTile(label: l10n.t("passport.busiestStation"), value: station.name, sub: l10n.t("passport.visitsCount", count: station.count), legId: nil)
            }
            if let leg = r.earliestDeparture {
                RecordTile(label: l10n.t("passport.earliest"), value: Format.time(leg.dep.ms, tz: Format.zone(leg.depTz), clock: app.settings.clock), sub: leg.from, legId: leg.legId)
            }
            if let leg = r.latestArrival {
                RecordTile(label: l10n.t("passport.latest"), value: Format.time(leg.arr.ms, tz: Format.zone(leg.arrTz), clock: app.settings.clock), sub: leg.to, legId: leg.legId)
            }
        }
    }
}

/// The Passport's map data as the one-ink map draws it (owner, 2026-11-07): every stretch once, with how often it was
/// ridden, and every station with its visits.
enum PassportMap {
    static func routes(_ data: Passport, dark: Bool) -> [MultiRoute] {
        let ink = MapStyle.colors(dark: dark).fallback
        return PassportLogic.routeWeights(data.map).map { w in
            MultiRoute(color: ink, geometry: w.geometry, stops: w.stops.compactMap { $0.count == 2 ? LatLon($0[0], $0[1]) : nil }, weight: w.count)
        }
    }

    static func stations(_ data: Passport) -> [MultiStation] {
        data.stations.map { MultiStation(lat: $0.lat, lon: $0.lon, name: $0.name, count: $0.count) }
    }
}

/// What the year chips say and do: all time, then each year with a trip (shared by the Passport and its map).
struct YearChips: View {
    @Environment(L10n.self) private var l10n
    let years: [Int]
    @Binding var year: Int?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ChipButton(text: l10n.t("passport.allTime"), active: year == nil) { year = nil }
                ForEach(years, id: \.self) { y in ChipButton(text: String(y), active: year == y) { year = y } }
            }
            .padding(.horizontal, 16)
        }
    }
}

/// "Your trains, all time" or "Your trains, 2026": which scope a pushed Passport screen shows.
func passportScopeLine(_ l10n: L10n, year: Int?) -> String {
    l10n.t("passport.scopeLine", ["scope": year.map(String.init) ?? l10n.t("passport.allTime").lowercased()])
}
