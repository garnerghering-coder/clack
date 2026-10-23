//
//  LiveMap.swift
//  Clack
//

import Foundation

/// One stop of a train on the live map, with what Trafikverket or Entur report for it (`GET /api/live/trains/:id/stops`,
/// `TrainView.stops`). Times are epoch ms.
nonisolated struct LiveTrainStop: Codable, Hashable, Sendable, Identifiable {
    let seq: Int
    let stationId: String
    let name: String
    let arr: Double?
    let dep: Double?
    let actualArr: Double?
    let actualDep: Double?
    let estimatedArr: Double?
    let estimatedDep: Double?
    let platform: String?
    let canceled: Bool
    /// Left this stop, or arrived at the last one.
    let passed: Bool

    var id: Int { seq }
}

/// The timetable trip a live train or a train view belongs to.
nonisolated struct TrainTrip: Codable, Hashable, Sendable {
    let key: String
    let serviceDate: String
    let from: StopRef?
    let to: StopRef?
}

/// `GET /api/live/trains/:id`: the train, its timetable trip and, when it's one of yours, your leg.
nonisolated struct LiveTrainDetail: Codable, Hashable, Sendable {
    let train: LiveTrain
    let trip: TrainTrip?
    let legId: String?
}

/// `GET /api/trains/:number/:date`: one train on one day, on the map or not. Looking, not following.
nonisolated struct TrainView: Codable, Hashable, Sendable {
    let number: String
    let date: String
    /// Its position on the live map, when it has one.
    let live: LiveTrain?
    let trip: TrainTrip?
    let operatorId: String?
    let productName: String?
    let product: String?
    let trainType: String?
    let stops: [LiveTrainStop]?
    let legId: String?
}

nonisolated struct LiveStopsAnswer: Codable, Sendable {
    let stops: [LiveTrainStop]
}

/// The first message of `GET /api/live/trains/stream`: every train in view.
nonisolated struct LiveSnapshot: Decodable, Sendable {
    let trains: [LiveTrain]
    let total: Int
    /// When the upstream feed last said anything; 0 = never.
    let upstreamAt: Double
    /// `stream`, `poll`, `simulate` or `stopped`.
    let mode: String?
}

/// A train whose only change is its position, sent as `[id, lat, lon, bearing, speedKmh, at, estimated]`.
nonisolated struct MovedTrain: Decodable, Hashable, Sendable {
    let id: String
    let lat: Double
    let lon: Double
    let bearing: Double?
    let speedKmh: Double?
    let at: Double
    let estimated: Bool

    init(from decoder: Decoder) throws {
        var c = try decoder.unkeyedContainer()
        id = try c.decode(String.self)
        lat = try c.decode(Double.self)
        lon = try c.decode(Double.self)
        bearing = try c.decodeIfPresent(Double.self)
        speedKmh = try c.decodeIfPresent(Double.self)
        at = try c.decode(Double.self)
        estimated = try c.decode(Bool.self)
    }
}

/// Every two seconds on the stream.
nonisolated struct LiveDelta: Decodable, Sendable {
    let changed: [LiveTrain]
    let moved: [MovedTrain]?
    let removed: [String]
    let total: Int
    let upstreamAt: Double
    let mode: String?
}

/// What `PUT /api/follows` takes.
nonisolated struct FollowBody: Encodable, Sendable {
    let trainNumber: String
    let serviceDate: String
    let operatorId: String?
    let label: String?
}
