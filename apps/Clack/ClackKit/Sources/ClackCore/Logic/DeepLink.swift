//
//  DeepLink.swift
//  Clack
//

import Foundation

/// Opens Add a train straight at the confirm step for a timetable trip (`clack://add?trip=K&date=D&from=&to=&replace=`).
public nonisolated struct AddTrainLink: Hashable, Sendable {
    public var tripKey: String
    public var date: String
    public var fromSeq: Int?
    public var toSeq: Int?
    /// A leg to mark "not taken" once this one is saved (replacing a cancelled train).
    public var replaceLegId: String?

    public init(tripKey: String, date: String, fromSeq: Int? = nil, toSeq: Int? = nil, replaceLegId: String? = nil) {
        self.tripKey = tripKey
        self.date = date
        self.fromSeq = fromSeq
        self.toSeq = toSeq
        self.replaceLegId = replaceLegId
    }
}

/// Where a `clack://` link leads: what widgets, the trip card, alerts and launch arguments open. The app turns it into
/// a tab and a pushed screen (`Router.open`); anything this does not recognise opens nothing.
///
/// | URL | Opens |
/// |---|---|
/// | `clack://trip/<legId>` | Trips, that trip |
/// | `clack://journey/<journeyId>` | Trips, that journey |
/// | `clack://board/<stationId>?arrivals=1` | Explore, that station's board (departures unless `arrivals=1`) |
/// | `clack://explore?train=N&date=YYYY-MM-DD&key=K` | Explore, that train focused (`key` optional) |
/// | `clack://explore`, `clack://trips`, `clack://passport`, `clack://tab/<tab>` | that tab, at its root |
/// | `clack://add` / `clack://add?trip=K&date=D&from=&to=&replace=` | Add a train (at its confirm step with a trip) |
/// | `clack://arrival/<legId>?journey=<journeyId>` | the arrival screen for that journey (`journey` optional) |
public nonisolated enum DeepLink: Hashable, Sendable {
    case trip(String)
    case journey(String)
    case board(stationId: String, arrivals: Bool)
    case train(number: String, date: String, key: String?)
    case tab(PrimaryTab)
    /// The Add a train sheet: at its confirm step for a trip, or empty.
    case add(AddTrainLink?)
    /// The end-of-journey screen; `legId` is the journey's last leg.
    case arrival(legId: String, journeyId: String?)

    public static let scheme = "clack"

    /// The tab the link shows, or nil when it opens over whatever tab is showing (the Add sheet, the arrival screen).
    public var tab: PrimaryTab? {
        switch self {
        case .trip, .journey: .trips
        case .board, .train: .explore
        case .tab(let tab): tab
        case .add, .arrival: nil
        }
    }

    public static func parse(_ url: URL) -> DeepLink? {
        guard url.scheme?.lowercased() == scheme,
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        else { return nil }
        // `clack://trip/x` has the kind as its host; `clack:trip/x` and `clack:///trip/x` have it in the path.
        let parts = ([components.host ?? ""] + components.path.split(separator: "/").map(String.init))
            .filter { !$0.isEmpty }
        guard let kind = parts.first?.lowercased() else { return nil }
        let id = parts.count > 1 ? parts[1] : nil
        var query: [String: String] = [:]
        for item in components.queryItems ?? [] {
            if let value = item.value?.trimmingCharacters(in: .whitespaces), !value.isEmpty, query[item.name] == nil {
                query[item.name] = value
            }
        }

        switch kind {
        case "trip":
            return id.map(DeepLink.trip)
        case "journey":
            return id.map(DeepLink.journey)
        case "board":
            guard let id else { return nil }
            return .board(stationId: id, arrivals: isTrue(query["arrivals"]))
        case "arrival":
            guard let id else { return nil }
            return .arrival(legId: id, journeyId: query["journey"])
        case "tab":
            return id.flatMap { PrimaryTab(rawValue: $0.lowercased()) }.map(DeepLink.tab)
        case "trips", "passport":
            return PrimaryTab(rawValue: kind).map(DeepLink.tab)
        case "explore":
            // A train needs both its number and its day; without them it's just the tab.
            if let number = query["train"], let date = query["date"], isDay(date) {
                return .train(number: number, date: date, key: query["key"])
            }
            return .tab(.explore)
        case "add":
            if let trip = query["trip"], let date = query["date"], isDay(date) {
                return .add(AddTrainLink(
                    tripKey: trip, date: date, fromSeq: query["from"].flatMap { Int($0) },
                    toSeq: query["to"].flatMap { Int($0) }, replaceLegId: query["replace"]
                ))
            }
            return .add(nil)
        default:
            return nil
        }
    }

    /// The link an alert opens: an arrival opens the arrival screen, a change the whole journey, anything else the trip.
    public static func forAlert(legId: String, journeyId: String?, kind: String) -> DeepLink {
        switch kind {
        case "arrival": .arrival(legId: legId, journeyId: journeyId)
        case "change": journeyId.map(DeepLink.journey) ?? .trip(legId)
        default: .trip(legId)
        }
    }

    /// The `clack://` URL for this link (what a widget or the trip card sets as its tap target).
    public var url: URL {
        var c = URLComponents()
        c.scheme = Self.scheme
        var items: [URLQueryItem] = []
        func add(_ name: String, _ value: String?) { if let value { items.append(URLQueryItem(name: name, value: value)) } }
        switch self {
        case .trip(let id): c.host = "trip"; c.path = "/\(id)"
        case .journey(let id): c.host = "journey"; c.path = "/\(id)"
        case .board(let id, let arrivals):
            c.host = "board"; c.path = "/\(id)"
            if arrivals { add("arrivals", "1") }
        case .train(let number, let date, let key):
            c.host = "explore"
            add("train", number); add("date", date); add("key", key)
        case .tab(let tab): c.host = "tab"; c.path = "/\(tab.rawValue)"
        case .add(let link):
            c.host = "add"
            if let link {
                add("trip", link.tripKey); add("date", link.date)
                add("from", link.fromSeq.map(String.init)); add("to", link.toSeq.map(String.init))
                add("replace", link.replaceLegId)
            }
        case .arrival(let legId, let journeyId):
            c.host = "arrival"; c.path = "/\(legId)"
            add("journey", journeyId)
        }
        if !items.isEmpty { c.queryItems = items }
        // Every part above is set from strings URLComponents encodes, so this always succeeds.
        return c.url ?? URL(string: "clack://")!
    }

    private static func isTrue(_ value: String?) -> Bool {
        guard let value = value?.lowercased() else { return false }
        return value == "1" || value == "true" || value == "yes"
    }

    /// A service day as the server writes it: `YYYY-MM-DD`.
    private static func isDay(_ value: String) -> Bool {
        let chars = Array(value)
        guard chars.count == 10 else { return false }
        return chars.indices.allSatisfy { i in i == 4 || i == 7 ? chars[i] == "-" : chars[i].isASCII && chars[i].isNumber }
    }
}
