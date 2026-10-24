//
//  WidgetStationPicker.swift
//  Clack
//
//  What the Departures widget's station picker fetches: the lists (favourites, recent, big stations), a search by name,
//  and a chosen station's name. Each asks the server first, within a few seconds, and falls back to `WidgetStations`,
//  the copy the app and earlier answers left in the App Group.
//

import Foundation

extension WidgetData {
    /// The popular list is fetched again after this long.
    public static let popularMaxAgeMs: Double = 24 * 3_600_000

    /// The picker's lists: from the server when it answers within `timeout` seconds (and then kept), else the kept copy.
    public static func stationLists(timeout: Double = 6, now: Double = Date.now.timeIntervalSince1970 * 1000) async -> WidgetStations {
        let kept = WidgetStations.load() ?? WidgetStations()
        guard let client = client() else { return kept }
        let askPopular = kept.popular.isEmpty || now - kept.popularAt > popularMaxAgeMs
        let fetched = await within(timeout) { () -> StationLists in
            async let favourites = try? client.favoriteStations()
            async let recent = try? client.recentStations()
            async let popular = askPopular ? (try? client.popularStations()) : nil
            return await StationLists(favourites: favourites, recent: recent, popular: popular)
        }
        guard let fetched else { return kept }
        let updated = merged(kept, fetched, now: now)
        if updated != kept { updated.save() }
        return updated
    }

    /// What the server sent for each list; nil for a list it didn't answer.
    public struct StationLists: Sendable {
        public var favourites: [StationHit]?
        public var recent: [StationHit]?
        public var popular: [StationHit]?

        public init(favourites: [StationHit]? = nil, recent: [StationHit]? = nil, popular: [StationHit]? = nil) {
            self.favourites = favourites
            self.recent = recent
            self.popular = popular
        }
    }

    /// The kept lists with what the server sent; a list it didn't send stays as it was.
    public static func merged(_ kept: WidgetStations, _ lists: StationLists, now: Double) -> WidgetStations {
        var s = kept
        if let favourites = lists.favourites { s.favourites = favourites.map(WidgetStations.Station.init) }
        if let recent = lists.recent { s.recent = recent.map(WidgetStations.Station.init) }
        if let popular = lists.popular {
            s.popular = popular.map(WidgetStations.Station.init)
            s.popularAt = now
        }
        s.remember(s.favourites + s.recent + s.popular)
        return s
    }

    /// Stations by name for the picker: the server's search (the Stations screen's), else the kept stations that match.
    /// Each hit is remembered so it can be named again once chosen.
    public static func searchStations(_ text: String, timeout: Double = 6) async -> [WidgetStations.Station] {
        let query = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return [] }
        var kept = WidgetStations.load() ?? WidgetStations()
        if let client = client(), let hits = await within(timeout, { try? await client.searchStations(query) }) ?? nil {
            let found = hits.map(WidgetStations.Station.init)
            kept.remember(found)
            kept.save()
            return found
        }
        return kept.search(query)
    }

    /// A chosen station's name: the kept lists, else the server.
    public static func station(_ id: String, timeout: Double = 6) async -> WidgetStations.Station? {
        if let known = WidgetStations.load()?.find(id) { return known }
        if let name = WidgetSnapshot.load()?.boards.first(where: { $0.id == id })?.name { return .init(id: id, name: name) }
        guard let client = client(), let info = await within(timeout, { try? await client.station(id) }) ?? nil else { return nil }
        let found = WidgetStations.Station(id: info.id, name: info.name)
        var kept = WidgetStations.load() ?? WidgetStations()
        kept.remember([found])
        kept.save()
        return found
    }
}
