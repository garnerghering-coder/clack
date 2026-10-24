//
//  Endpoints.swift
//  Clack
//

import Foundation

/// The server's endpoints the app uses, one function each (docs/swift-port/API.md). Ids go in the path as-is:
/// `APIClient.url` percent-encodes every segment.
extension APIClient {
    public func settings() async throws -> Settings { try await get(["settings"]) }

    /// Changes some settings; the answer is the full merged settings.
    public func updateSettings(_ patch: SettingsPatch) async throws -> Settings { try await send("PATCH", ["settings"], body: patch) }

    /// "Delete my data": everything the server keeps under this phone's id.
    public func deleteMyData() async throws { try await perform("DELETE", ["me"]) }
    /// This phone can receive alerts (`PUT /api/devices`): Apple's address for it, which of Apple's push servers it
    /// belongs to, and the trip card's push-to-start address when known (see `DeviceRegistration`: a missing key keeps
    /// the stored one).
    public func registerDevice(_ body: DeviceRegistration) async throws {
        try await perform("PUT", ["devices"], body: body)
    }

    public func forgetDevice(_ token: String) async throws { try await perform("DELETE", ["devices", token]) }

    /// A Live Activity is running for this trip: where the server sends its updates, and the phone it is on.
    public func registerActivity(_ body: ActivityRegistration) async throws {
        try await perform("PUT", ["live-activities"], body: body)
    }

    public func forgetActivity(_ token: String) async throws { try await perform("DELETE", ["live-activities", token]) }

    /// The commit the server runs (`GET /api/health`), shown at the bottom of Settings.
    public func serverVersion() async throws -> String {
        nonisolated struct Health: Decodable, Sendable { let version: String? }
        let health: Health = try await get(["health"])
        return health.version ?? "unknown"
    }

    public func operators() async throws -> [Operator] { try await get(["operators"]) }
    public func trainTypes() async throws -> [TrainType] { try await get(["train-types"]) }
    public func amenities() async throws -> [AmenityEntry] { try await get(["amenities"]) }

    public func legs() async throws -> [Leg] { try await get(["legs"]) }
    public func leg(_ id: String) async throws -> LegDetail { try await get(["legs", id]) }
    public func journey(_ id: String) async throws -> Journey { try await get(["journeys", id]) }
    public func follows() async throws -> [Follow] { try await get(["follows"]) }

    public func station(_ id: String) async throws -> StationInfo { try await get(["stations", id]) }
    public func stationMap(_ id: String) async throws -> StationMap { try await get(["stations", id, "map"]) }

    /// "Did you take this train?": answers yes, no, or undo.
    public func answerRide(_ legId: String, _ answer: RideAnswer) async throws -> LegDetail {
        struct Body: Encodable, Sendable { let answer: RideAnswer }
        return try await send("POST", ["legs", legId, "ride"], body: Body(answer: answer))
    }

    public func refreshLeg(_ id: String) async throws -> LegDetail { try await send("POST", ["legs", id, "refresh"]) }
    public func deleteLeg(_ id: String) async throws { try await perform("DELETE", ["legs", id]) }

    /// Sets the train type of a trip; nil goes back to the typical one.
    public func setTrainType(_ legId: String, _ trainType: String?) async throws -> LegDetail {
        struct Body: Encodable, Sendable {
            let trainType: String?
            // The key must be present even when null: a missing key means "nothing to change".
            func encode(to encoder: Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                try container.encode(trainType, forKey: .trainType)
            }
            enum CodingKeys: String, CodingKey { case trainType }
        }
        return try await send("PATCH", ["legs", legId], body: Body(trainType: trainType))
    }

    public func legRisk(_ id: String) async throws -> LegRisk { try await get(["legs", id, "risk"]) }
    public func tripProgress(_ id: String) async throws -> TripProgress { try await get(["legs", id, "progress"]) }

    public func alternatives(from: String, to: String, after: Double, exclude: String?) async throws -> Alternatives {
        var query = ["from": from, "to": to, "after": String(Int(after.rounded()))]
        if let exclude { query["exclude"] = exclude }
        return try await get(["alternatives"], query: query)
    }

    public func search(_ text: String, date: String) async throws -> SearchResponse {
        try await get(["search"], query: ["q": text, "date": date])
    }

    public func popularStations() async throws -> [StationHit] { try await get(["stations", "popular"]) }

    public func searchStations(_ text: String, limit: Int = 12) async throws -> [StationHit] {
        try await get(["stations", "search"], query: ["q": text, "limit": String(limit)])
    }

    public func timetableTrip(_ key: String, date: String) async throws -> TimetableTrip {
        try await get(["timetable", "trips", key], query: ["date": date])
    }

    public func timetableTripGeometry(_ key: String, date: String) async throws -> TripGeometry {
        try await get(["timetable", "trips", key, "geometry"], query: ["date": date])
    }

    /// Saves a timetable trip; a 409 (`APIError.duplicateOf`) means the same train is already saved on that date.
    public func createLeg(_ body: CreateLegBody) async throws -> LegDetail { try await send("POST", ["legs"], body: body) }

    public func createManualLeg(_ body: ManualLegBody) async throws -> LegDetail { try await send("POST", ["legs", "manual"], body: body) }

    /// The Passport for a year (nil = all time). Commuter trains and the CO2 comparison are asked for explicitly.
    public func passport(year: Int?, commuter: Bool, comparison: Co2Comparison) async throws -> Passport {
        var query = ["year": year.map(String.init) ?? "all", "commuter": commuter ? "true" : "false"]
        query["comparison"] = comparison.rawValue
        return try await get(["passport"], query: query)
    }

    // MARK: station lists and boards

    public func favoriteStations() async throws -> [StationHit] { try await get(["stations", "favorites"]) }
    public func recentStations() async throws -> [StationHit] { try await get(["stations", "recent"]) }
    public func stationViewed(_ id: String) async throws { try await perform("POST", ["stations", id, "viewed"]) }

    public nonisolated struct FavoriteAnswer: Decodable, Sendable { let favorite: Bool }

    public func setFavorite(_ id: String, _ on: Bool) async throws -> Bool {
        let answer: FavoriteAnswer = try await send(on ? "PUT" : "DELETE", ["stations", id, "favorite"])
        return answer.favorite
    }

    /// The board once; `window` asks for another span of time (the "show earlier" rows).
    public func board(_ id: String, arrivals: Bool, from: Double? = nil, to: Double? = nil) async throws -> Board {
        var query = ["type": arrivals ? "arrivals" : "departures"]
        if let from, let to {
            query["from"] = String(Int64(from))
            query["to"] = String(Int64(to))
        }
        return try await get(["stations", id, "board"], query: query)
    }

    /// `GET /api/stations/:id/board/stream`: the current board at once, then after every shared poll.
    public func boardStream(_ id: String, arrivals: Bool) -> AsyncThrowingStream<SSEEvent, Error> {
        EventStream.events(url: url(["stations", id, "board", "stream"], query: ["type": arrivals ? "arrivals" : "departures"]), userID: userID)
    }

    // MARK: live map

    public func liveTrain(_ id: String) async throws -> LiveTrainDetail { try await get(["live", "trains", id]) }
    public func liveTrainStops(_ id: String) async throws -> [LiveTrainStop] {
        let answer: LiveStopsAnswer = try await get(["live", "trains", id, "stops"])
        return answer.stops
    }

    public func train(number: String, date: String, key: String?) async throws -> TrainView {
        try await get(["trains", number, date], query: key.map { ["key": $0] } ?? [:])
    }

    public nonisolated struct FollowingAnswer: Decodable, Sendable { let following: Bool }

    public func follow(_ body: FollowBody) async throws {
        let _: FollowingAnswer = try await send("PUT", ["follows"], body: body)
    }

    public func unfollow(number: String, date: String) async throws {
        try await perform("DELETE", ["follows", number, date])
    }

    /// `GET /api/live/trains/stream?bbox=W,S,E,N`: a snapshot, then a delta every 2 s.
    public func liveTrainStream(bbox: String) -> AsyncThrowingStream<SSEEvent, Error> {
        EventStream.events(url: url(["live", "trains", "stream"], query: ["bbox": bbox]), userID: userID)
    }
}
