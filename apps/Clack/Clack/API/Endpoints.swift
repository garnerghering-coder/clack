//
//  Endpoints.swift
//  Clack
//

import Foundation

/// The server's endpoints the app uses, one function each (docs/swift-port/API.md). Ids go in the path as-is:
/// `APIClient.url` percent-encodes every segment.
extension APIClient {
    func settings() async throws -> Settings { try await get(["settings"]) }

    /// Changes some settings; the answer is the full merged settings.
    func updateSettings(_ patch: SettingsPatch) async throws -> Settings { try await send("PATCH", ["settings"], body: patch) }

    /// "Delete my data": everything the server keeps under this phone's id.
    func deleteMyData() async throws { try await perform("DELETE", ["me"]) }
    func operators() async throws -> [Operator] { try await get(["operators"]) }
    func trainTypes() async throws -> [TrainType] { try await get(["train-types"]) }
    func amenities() async throws -> [AmenityEntry] { try await get(["amenities"]) }

    func legs() async throws -> [Leg] { try await get(["legs"]) }
    func leg(_ id: String) async throws -> LegDetail { try await get(["legs", id]) }
    func journey(_ id: String) async throws -> Journey { try await get(["journeys", id]) }
    func follows() async throws -> [Follow] { try await get(["follows"]) }

    func station(_ id: String) async throws -> StationInfo { try await get(["stations", id]) }
    func stationMap(_ id: String) async throws -> StationMap { try await get(["stations", id, "map"]) }

    /// "Did you take this train?": answers yes, no, or undo.
    func answerRide(_ legId: String, _ answer: RideAnswer) async throws -> LegDetail {
        struct Body: Encodable, Sendable { let answer: RideAnswer }
        return try await send("POST", ["legs", legId, "ride"], body: Body(answer: answer))
    }

    func refreshLeg(_ id: String) async throws -> LegDetail { try await send("POST", ["legs", id, "refresh"]) }
    func deleteLeg(_ id: String) async throws { try await perform("DELETE", ["legs", id]) }

    /// Sets the train type of a trip; nil goes back to the typical one.
    func setTrainType(_ legId: String, _ trainType: String?) async throws -> LegDetail {
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

    func legRisk(_ id: String) async throws -> LegRisk { try await get(["legs", id, "risk"]) }
    func tripProgress(_ id: String) async throws -> TripProgress { try await get(["legs", id, "progress"]) }

    func alternatives(from: String, to: String, after: Double, exclude: String?) async throws -> Alternatives {
        var query = ["from": from, "to": to, "after": String(Int(after.rounded()))]
        if let exclude { query["exclude"] = exclude }
        return try await get(["alternatives"], query: query)
    }

    func search(_ text: String, date: String) async throws -> SearchResponse {
        try await get(["search"], query: ["q": text, "date": date])
    }

    func popularStations() async throws -> [StationHit] { try await get(["stations", "popular"]) }

    func searchStations(_ text: String, limit: Int = 12) async throws -> [StationHit] {
        try await get(["stations", "search"], query: ["q": text, "limit": String(limit)])
    }

    func timetableTrip(_ key: String, date: String) async throws -> TimetableTrip {
        try await get(["timetable", "trips", key], query: ["date": date])
    }

    func timetableTripGeometry(_ key: String, date: String) async throws -> TripGeometry {
        try await get(["timetable", "trips", key, "geometry"], query: ["date": date])
    }

    /// Saves a timetable trip; a 409 (`APIError.duplicateOf`) means the same train is already saved on that date.
    func createLeg(_ body: CreateLegBody) async throws -> LegDetail { try await send("POST", ["legs"], body: body) }

    func createManualLeg(_ body: ManualLegBody) async throws -> LegDetail { try await send("POST", ["legs", "manual"], body: body) }

    /// The Passport for a year (nil = all time). Commuter trains and the CO2 comparison are asked for explicitly.
    func passport(year: Int?, commuter: Bool, comparison: Co2Comparison) async throws -> Passport {
        var query = ["year": year.map(String.init) ?? "all", "commuter": commuter ? "true" : "false"]
        query["comparison"] = comparison.rawValue
        return try await get(["passport"], query: query)
    }

    // MARK: station lists and boards

    func favoriteStations() async throws -> [StationHit] { try await get(["stations", "favorites"]) }
    func recentStations() async throws -> [StationHit] { try await get(["stations", "recent"]) }
    func stationViewed(_ id: String) async throws { try await perform("POST", ["stations", id, "viewed"]) }

    nonisolated struct FavoriteAnswer: Decodable, Sendable { let favorite: Bool }

    func setFavorite(_ id: String, _ on: Bool) async throws -> Bool {
        let answer: FavoriteAnswer = try await send(on ? "PUT" : "DELETE", ["stations", id, "favorite"])
        return answer.favorite
    }

    /// The board once; `window` asks for another span of time (the "show earlier" rows).
    func board(_ id: String, arrivals: Bool, from: Double? = nil, to: Double? = nil) async throws -> Board {
        var query = ["type": arrivals ? "arrivals" : "departures"]
        if let from, let to {
            query["from"] = String(Int64(from))
            query["to"] = String(Int64(to))
        }
        return try await get(["stations", id, "board"], query: query)
    }

    /// `GET /api/stations/:id/board/stream`: the current board at once, then after every shared poll.
    func boardStream(_ id: String, arrivals: Bool) -> AsyncThrowingStream<SSEEvent, Error> {
        EventStream.events(url: url(["stations", id, "board", "stream"], query: ["type": arrivals ? "arrivals" : "departures"]), userID: userID)
    }
}
