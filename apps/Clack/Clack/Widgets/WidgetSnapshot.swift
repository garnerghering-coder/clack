//
//  WidgetSnapshot.swift
//  Clack
//

import Foundation

/// What the app hands to the Home Screen and Lock Screen widgets (owner, 2026-10-24). The app writes it after each refresh into the
/// App Group container, and the widgets read it, so they work between refreshes and with no connection. This file exists twice,
/// identical: here and in ClackWidgets. Without the App Group (a Personal Team can't have one) there is no container: the app writes
/// nothing and the widgets show sample data until the group `WidgetSnapshot.groupId` is added to both targets.
struct WidgetSnapshot: Codable, Equatable {
    static let groupId = "group.com.garnerghering.Clack"
    static let fileName = "widget-snapshot.json"

    var updatedAt: Double = 0
    /// The next (or running) journey, its legs in order, those not finished yet.
    var journey: [Leg] = []
    var passport: PassportBits?
    var stats: StatsBits?
    var year: YearBits?
    var boards: [StationBoard] = []

    struct Leg: Codable, Equatable, Identifiable {
        var id: String
        var journeyId: String?
        var operatorName: String?
        /// `#rrggbb`.
        var color: String?
        var train: String?
        var from: String
        var to: String
        var fromTz: String
        var toTz: String
        /// Expected times (ms since 1970): actual, else live estimate, else timetable plus delay.
        var depAt: Double
        var arrAt: Double
        var depPlatform: String?
        var arrPlatform: String?
        var delayMin: Int?
        var canceled: Bool
        /// The last live status the server sent (`scheduled`, `approaching`, `boarding`, `en_route`, `at_stop`, `arrived`).
        var status: String?
        var progress: Double?
        var nextStop: String?
        var nextStopAt: Double?
        /// Names of the stops ridden, in order.
        var stops: [String] = []
    }

    struct PassportBits: Codable, Equatable {
        var km: Double
        var trains: Int
        var journeys: Int
        var stations: Int
        var countries: Int
        var minutes: Double
        var year: Int?
        var onTimePct: Double?
        var lateMinutes: Double
        var co2SavedKg: Double?
        var co2Comparison: String
        var nextMedal: String?
        var nextMedalValue: Double?
        var nextMedalTarget: Double?
    }

    struct Row: Codable, Equatable, Identifiable {
        var name: String
        var count: Int
        var color: String?
        var id: String { name }
    }

    struct StatsBits: Codable, Equatable {
        var operators: [Row]
        var trainTypes: [Row]
        var stations: [Row]
        var countries: [Row]
    }

    struct YearBits: Codable, Equatable {
        var year: Int
        var km: Double
        var trains: Int
        var topRoute: String?
        var topRouteCount: Int
        var busiestMonth: String?
        var busiestMonthCount: Int
        /// Every ride as a thinned line of `[lat, lon]` points.
        var routes: [[[Double]]]
    }

    struct Departure: Codable, Equatable, Identifiable {
        var id: String
        var time: Double
        var delayMin: Int?
        var platform: String?
        var to: String
        var train: String
        var canceled: Bool
    }

    struct StationBoard: Codable, Equatable, Identifiable {
        var id: String
        var name: String
        var rows: [Departure]
    }

    // MARK: the shared file

    static var containerURL: URL? { FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: groupId) }

    static func load() -> WidgetSnapshot? {
        guard let url = containerURL?.appendingPathComponent(fileName), let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
    }

    /// False when there is no App Group to write into.
    @discardableResult
    func save() -> Bool {
        guard let url = Self.containerURL?.appendingPathComponent(Self.fileName), let data = try? JSONEncoder().encode(self) else { return false }
        return (try? data.write(to: url, options: .atomic)) != nil
    }
}

// MARK: where the journey is now

/// The moment of a journey, from the snapshot and the clock alone (so each timeline entry can work it out, offline too).
nonisolated enum JourneyMoment: Equatable {
    /// Before the first departure.
    case before(leg: Int)
    /// On a train: the leg and how far along (0-1).
    case onTrain(leg: Int, progress: Double)
    /// Between two legs: the next leg and the minutes until it leaves.
    case changing(next: Int, spareMin: Int)
    case finished

    static func at(_ now: Double, legs: [WidgetSnapshot.Leg]) -> JourneyMoment {
        guard let first = legs.first, let last = legs.last else { return .finished }
        if now >= last.arrAt { return .finished }
        if now < first.depAt { return .before(leg: 0) }
        for (i, leg) in legs.enumerated() {
            if now >= leg.depAt && now < leg.arrAt {
                let span = max(1, leg.arrAt - leg.depAt)
                return .onTrain(leg: i, progress: min(1, max(0, (now - leg.depAt) / span)))
            }
            if i + 1 < legs.count, now >= leg.arrAt, now < legs[i + 1].depAt {
                return .changing(next: i + 1, spareMin: Int(((legs[i + 1].depAt - now) / 60_000).rounded(.up)))
            }
        }
        return .finished
    }

    /// The leg the widget talks about.
    var legIndex: Int? {
        switch self {
        case .before(let i), .onTrain(let i, _), .changing(let i, _): return i
        case .finished: return nil
        }
    }
}
