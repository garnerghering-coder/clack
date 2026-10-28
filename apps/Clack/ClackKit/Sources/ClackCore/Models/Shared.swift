//
//  Shared.swift
//  Clack
//

import Foundation

/// A journey someone shared by link, as a follower is allowed to see it (`GET /api/shared/<token>`): the trains, times,
/// platforms and where it is. It has nothing of the traveller's: no id, no seat, no ticket, no other trip.
public nonisolated struct SharedJourney: Codable, Hashable, Sendable, Identifiable {
    public var id: String { token }
    public let token: String
    /// When the link stops working (ms).
    public let expiresAt: Double
    public let summary: Summary
    public let legs: [Leg]
    public let changes: [Change]

    public nonisolated enum Phase: String, Codable, Sendable {
        case upcoming, underway, atChange, arrived, cancelled
    }

    public struct Summary: Codable, Hashable, Sendable {
        public let phase: Phase
        /// The train now running, or the next to run.
        public let legIndex: Int
        public let from: String
        public let to: String
        public let departureAt: Double?
        public let arrivalAt: Double?
        public let arrivalDelayMin: Int?
        public let arrivalPlatform: String?
        /// While underway: the stop it left and the one it heads for.
        public let between: Between?

        public struct Between: Codable, Hashable, Sendable {
            public let from: String
            public let to: String
        }

        public init(phase: Phase, legIndex: Int, from: String, to: String, departureAt: Double?, arrivalAt: Double?, arrivalDelayMin: Int?, arrivalPlatform: String?, between: Between?) {
            self.phase = phase
            self.legIndex = legIndex
            self.from = from
            self.to = to
            self.departureAt = departureAt
            self.arrivalAt = arrivalAt
            self.arrivalDelayMin = arrivalDelayMin
            self.arrivalPlatform = arrivalPlatform
            self.between = between
        }
    }

    public struct Operator: Codable, Hashable, Sendable {
        public let id: String
        public let name: String
        public let shortName: String
        public let brandColor: String
        public let logoUrl: String?
    }

    public struct Place: Codable, Hashable, Sendable {
        public let name: String
        public let tz: String
    }

    public struct Stop: Codable, Hashable, Sendable {
        public let name: String
        public let tz: String
        public let arr: Double?
        public let dep: Double?
        public let schedArr: Double?
        public let schedDep: Double?
        public let platform: String?
        public let canceled: Bool
        public let passed: Bool
        /// Why it's late or changed here, as the source said it. Nil from servers before build 43.
        public let causes: [LegStop.Cause]?
    }

    public struct Live: Codable, Hashable, Sendable {
        public let status: String
        public let lat: Double?
        public let lon: Double?
        public let bearing: Double?
        /// `gps` or `estimated`.
        public let positionSource: String?
        public let progress: Double?
        public let nextStop: String?
        public let nextStopAt: Double?
        public let updatedAt: Double
    }

    public struct Leg: Codable, Hashable, Sendable {
        public let `operator`: Operator?
        public let trainNumber: String?
        public let serviceDate: String?
        public let from: Place
        public let to: Place
        public let schedDep: Double?
        public let schedArr: Double?
        public let expDep: Double?
        public let expArr: Double?
        public let depPlatform: String?
        public let arrPlatform: String?
        public let depDelayMin: Int?
        public let arrDelayMin: Int?
        public let canceled: Bool
        public let departed: Bool
        public let arrived: Bool
        /// The route as an encoded polyline.
        public let geometry: String?
        public let live: Live?
        public let stops: [Stop]

        /// "SJ 547".
        public var service: String { [`operator`?.shortName, trainNumber].compactMap { $0 }.joined(separator: " ") }
    }

    public struct Change: Codable, Hashable, Sendable {
        /// Between `legs[index]` and `legs[index + 1]`.
        public let index: Int
        public let station: String
        /// The trains meet at one station (else it is a walk between two).
        public let sameStation: Bool
        public let spareMin: Int?
        public let arrPlatform: String?
        public let depPlatform: String?
        public let status: Status

        public nonisolated enum Status: String, Codable, Sendable {
            case ok, tight, missed, unknown
        }
    }
}

/// What `POST /api/share/journey` and `GET /api/share` answer.
public nonisolated struct ShareLink: Codable, Hashable, Sendable {
    /// Nil from `GET /api/share` when the journey is not shared.
    public let token: String?
    public let url: String?
    public let expiresAt: Double?
}
