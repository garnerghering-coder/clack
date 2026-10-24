//
//  WidgetStations.swift
//  Clack
//
//  The stations the Departures widget's picker offers (Edit Widget > Station): your favourites, the stations you looked
//  at lately and the big stations, as the app last saw them, kept in the App Group next to the snapshot. The picker asks
//  the server first and falls back to this copy, so the list is never empty because the extension couldn't reach the
//  server or read the phone's id (owner, 2026-10-24: "Choose a station doesn't work"). Every station the picker has
//  offered is remembered by id, so a chosen one can be named again without the network.
//

import Foundation

public nonisolated struct WidgetStations: Codable, Equatable, Sendable {
    public struct Station: Codable, Hashable, Sendable, Identifiable {
        public var id: String
        public var name: String

        public init(id: String, name: String) {
            self.id = id
            self.name = name
        }

        public init(_ hit: StationHit) { self.init(id: hit.id, name: hit.name) }
    }

    public static let fileName = "widget-stations.json"
    /// How many stations are remembered by id.
    public static let knownLimit = 300

    public var favourites: [Station] = []
    public var recent: [Station] = []
    public var popular: [Station] = []
    /// Every station offered so far, newest first.
    public var known: [Station] = []
    /// When the popular list was fetched (ms since 1970); it changes rarely.
    public var popularAt: Double = 0

    public init(favourites: [Station] = [], recent: [Station] = [], popular: [Station] = [], known: [Station] = [], popularAt: Double = 0) {
        self.favourites = favourites
        self.recent = recent
        self.popular = popular
        self.known = known
        self.popularAt = popularAt
    }

    /// The lists for the picker, in order, each station once (a favourite isn't listed again under recent).
    public var sections: [(kind: Section, stations: [Station])] {
        var seen = Set<String>()
        func fresh(_ list: [Station]) -> [Station] { list.filter { seen.insert($0.id).inserted } }
        return [(Section.favourites, fresh(favourites)), (.recent, fresh(recent)), (.popular, fresh(popular))].filter { !$0.1.isEmpty }
    }

    public enum Section: String, Sendable {
        case favourites, recent, popular

        /// The L10n key of the section's title (the Stations lists' own headings).
        public var titleKey: String {
            switch self {
            case .favourites: "stations.favorites"
            case .recent: "stations.recent"
            case .popular: "stations.popular"
            }
        }
    }

    /// Adds stations to the ones known by id (newest first, at most `knownLimit`).
    public mutating func remember(_ stations: [Station]) {
        let ids = Set(stations.map(\.id))
        known = Array((stations + known.filter { !ids.contains($0.id) }).prefix(Self.knownLimit))
    }

    /// A station by id from any list.
    public func find(_ id: String) -> Station? {
        (favourites + recent + popular + known).first { $0.id == id }
    }

    /// The known stations whose name matches the text (ignoring case and accents), those starting with it first: the
    /// search when the server can't be reached.
    public func search(_ text: String) -> [Station] {
        let needle = Self.fold(text)
        guard !needle.isEmpty else { return [] }
        var seen = Set<String>()
        let all = (favourites + recent + popular + known).filter { seen.insert($0.id).inserted }
        let hits = all.filter { Self.fold($0.name).contains(needle) }
        return hits.filter { Self.fold($0.name).hasPrefix(needle) } + hits.filter { !Self.fold($0.name).hasPrefix(needle) }
    }

    static func fold(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines).folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
    }

    // MARK: the shared file

    public static func load() -> WidgetStations? {
        guard let url = WidgetSnapshot.containerURL?.appendingPathComponent(fileName), let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(WidgetStations.self, from: data)
    }

    @discardableResult
    public func save() -> Bool {
        guard let dir = WidgetSnapshot.containerURL, let data = try? JSONEncoder().encode(self) else { return false }
        return (try? data.write(to: dir.appendingPathComponent(Self.fileName), options: .atomic)) != nil
    }

    public static func clear() {
        guard let dir = WidgetSnapshot.containerURL else { return }
        try? FileManager.default.removeItem(at: dir.appendingPathComponent(fileName))
    }
}
