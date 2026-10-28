//
//  LiveMap.swift
//  Clack
//

import Foundation

/// One stop of a train on the live map, with what Trafikverket or Entur report for it (`GET /api/live/trains/:id/stops`,
/// `TrainView.stops`). Times are epoch ms.
public nonisolated struct LiveTrainStop: Codable, Hashable, Sendable, Identifiable {
    public let seq: Int
    public let stationId: String
    public let name: String
    public let arr: Double?
    public let dep: Double?
    public let actualArr: Double?
    public let actualDep: Double?
    public let estimatedArr: Double?
    public let estimatedDep: Double?
    public let platform: String?
    public let canceled: Bool
    /// Left this stop, or arrived at the last one.
    public let passed: Bool
    /// Why it's late or changed here, as the source said it. Nil from servers before build 43.
    public let causes: [LegStop.Cause]?

    public var id: Int { seq }

    public init(seq: Int, stationId: String, name: String, arr: Double?, dep: Double?, actualArr: Double?, actualDep: Double?, estimatedArr: Double?, estimatedDep: Double?, platform: String?, canceled: Bool, passed: Bool, causes: [LegStop.Cause]? = nil) {
        self.seq = seq
        self.stationId = stationId
        self.name = name
        self.arr = arr
        self.dep = dep
        self.actualArr = actualArr
        self.actualDep = actualDep
        self.estimatedArr = estimatedArr
        self.estimatedDep = estimatedDep
        self.platform = platform
        self.canceled = canceled
        self.passed = passed
        self.causes = causes
    }
}

/// The timetable trip a live train or a train view belongs to.
public nonisolated struct TrainTrip: Codable, Hashable, Sendable {
    public let key: String
    public let serviceDate: String
    public let from: StopRef?
    public let to: StopRef?

    public init(key: String, serviceDate: String, from: StopRef?, to: StopRef?) {
        self.key = key
        self.serviceDate = serviceDate
        self.from = from
        self.to = to
    }
}

/// `GET /api/live/trains/:id`: the train, its timetable trip and, when it's one of yours, your leg.
public nonisolated struct LiveTrainDetail: Codable, Hashable, Sendable {
    public let train: LiveTrain
    public let trip: TrainTrip?
    public let legId: String?

    public init(train: LiveTrain, trip: TrainTrip?, legId: String?) {
        self.train = train
        self.trip = trip
        self.legId = legId
    }
}

/// `GET /api/trains/:number/:date`: one train on one day, on the map or not. Looking, not following.
public nonisolated struct TrainView: Codable, Hashable, Sendable {
    public let number: String
    public let date: String
    /// Its position on the live map, when it has one.
    public let live: LiveTrain?
    public let trip: TrainTrip?
    public let operatorId: String?
    public let productName: String?
    public let product: String?
    public let trainType: String?
    public let stops: [LiveTrainStop]?
    public let legId: String?

    public init(number: String, date: String, live: LiveTrain?, trip: TrainTrip?, operatorId: String?, productName: String?, product: String?, trainType: String?, stops: [LiveTrainStop]?, legId: String?) {
        self.number = number
        self.date = date
        self.live = live
        self.trip = trip
        self.operatorId = operatorId
        self.productName = productName
        self.product = product
        self.trainType = trainType
        self.stops = stops
        self.legId = legId
    }
}

public nonisolated struct LiveStopsAnswer: Codable, Sendable {
    public let stops: [LiveTrainStop]

    public init(stops: [LiveTrainStop]) {
        self.stops = stops
    }
}

/// The first message of `GET /api/live/trains/stream`: every train in view.
public nonisolated struct LiveSnapshot: Decodable, Sendable {
    public let trains: [LiveTrain]
    public let total: Int
    /// When the upstream feed last said anything; 0 = never.
    public let upstreamAt: Double
    /// `stream`, `poll`, `simulate` or `stopped`.
    public let mode: String?

    public init(trains: [LiveTrain], total: Int, upstreamAt: Double, mode: String?) {
        self.trains = trains
        self.total = total
        self.upstreamAt = upstreamAt
        self.mode = mode
    }
}

/// A train whose only change is its position, sent as `[id, lat, lon, bearing, speedKmh, at, estimated]`.
public nonisolated struct MovedTrain: Decodable, Hashable, Sendable {
    public let id: String
    public let lat: Double
    public let lon: Double
    public let bearing: Double?
    public let speedKmh: Double?
    public let at: Double
    public let estimated: Bool

    public init(from decoder: Decoder) throws {
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
public nonisolated struct LiveDelta: Decodable, Sendable {
    public let changed: [LiveTrain]
    public let moved: [MovedTrain]?
    public let removed: [String]
    public let total: Int
    public let upstreamAt: Double
    public let mode: String?

    public init(changed: [LiveTrain], moved: [MovedTrain]?, removed: [String], total: Int, upstreamAt: Double, mode: String?) {
        self.changed = changed
        self.moved = moved
        self.removed = removed
        self.total = total
        self.upstreamAt = upstreamAt
        self.mode = mode
    }
}

/// What `PUT /api/follows` takes.
public nonisolated struct FollowBody: Encodable, Sendable {
    public let trainNumber: String
    public let serviceDate: String
    public let operatorId: String?
    public let label: String?

    public init(trainNumber: String, serviceDate: String, operatorId: String?, label: String?) {
        self.trainNumber = trainNumber
        self.serviceDate = serviceDate
        self.operatorId = operatorId
        self.label = label
    }
}
