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

    /// Changes a saved trip: its train type, coach or seat (`LegPatch`: what's left out stays as it is).
    public func updateLeg(_ legId: String, _ patch: LegPatch) async throws -> LegDetail {
        try await send("PATCH", ["legs", legId], body: patch)
    }

    /// Sets the train type of a trip; nil goes back to the typical one.
    public func setTrainType(_ legId: String, _ trainType: String?) async throws -> LegDetail {
        try await updateLeg(legId, LegPatch(trainType: .some(trainType)))
    }

    public func legRisk(_ id: String) async throws -> LegRisk { try await get(["legs", id, "risk"]) }
    public func tripProgress(_ id: String) async throws -> TripProgress { try await get(["legs", id, "progress"]) }

    public func alternatives(from: String, to: String, after: Double, exclude: String?) async throws -> Alternatives {
        var query = ["from": from, "to": to, "after": String(Int(after.rounded()))]
        if let exclude { query["exclude"] = exclude }
        return try await get(["alternatives"], query: query)
    }

    /// `changes` (0–5) is the most changes a journey may have; `after` (epoch ms) and `hours` ask for one window of
    /// journeys instead of the whole service day, for paging earlier and later (the window may run into the next day).
    public func search(_ text: String, date: String, changes: Int? = nil, after: Double? = nil, hours: Int? = nil) async throws -> SearchResponse {
        var query = ["q": text, "date": date]
        if let changes { query["changes"] = String(changes) }
        if let after { query["after"] = String(Int64(after)) }
        if let hours { query["hours"] = String(hours) }
        return try await get(["search"], query: query)
    }

    /// Starts fetching an older day's timetable as soon as the day is picked, so it's ready when the search runs.
    /// Answers at once; what it says isn't needed (the search reports the same).
    public func prepareHistory(date: String) async throws {
        let _: HistoryPrepared = try await get(["history", "prepare"], query: ["date": date])
    }

    public func popularStations() async throws -> [StationHit] { try await get(["stations", "popular"]) }
    /// Real trains leaving within the hour, near a position when given, else from the big stations.
    public func trainsSoon(lat: Double? = nil, lon: Double? = nil) async throws -> [SoonTrain] {
        var query: [String: String] = [:]
        // Rounded to about a kilometre: enough for the nearest stations, and the server doesn't keep it.
        if let lat, let lon { query = ["lat": String(format: "%.2f", lat), "lon": String(format: "%.2f", lon)] }
        return try await get(["trains", "soon"], query: query)
    }

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
    /// Where trains are running late now (the network status panel on Explore).
    public func networkStatus() async throws -> NetworkStatus { try await get(["live", "network"]) }
    /// The track between two stops (`GET /api/live/segment?from&to`; ids as in `LiveTrain.prevId`/`nextId`).
    public func liveSegment(from: String, to: String) async throws -> LiveSegment {
        try await get(["live", "segment"], query: ["from": from, "to": to])
    }
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
    // MARK: sharing a journey

    public nonisolated struct ShareBody: Encodable, Sendable {
        public let journeyId: String?
        public let legId: String?
    }

    /// Makes (or finds) the link for a journey, or for a trip that stands alone.
    public func shareJourney(journeyId: String?, legId: String?) async throws -> ShareLink {
        try await send("POST", ["share", "journey"], body: ShareBody(journeyId: journeyId, legId: legId))
    }

    /// The link the journey has now, if it is shared (`token` is nil when not).
    public func currentShare(journeyId: String?, legId: String?) async throws -> ShareLink {
        var query: [String: String] = [:]
        if let journeyId { query["journeyId"] = journeyId }
        if let legId { query["legId"] = legId }
        return try await get(["share"], query: query)
    }

    public func stopSharing(token: String) async throws {
        try await perform("DELETE", ["share", token])
    }

    /// What a link shows, for anyone: the journey as a follower sees it.
    public func sharedJourney(token: String) async throws -> SharedJourney {
        try await get(["shared", token])
    }

    /// Follows a shared journey (alerts for it, and a card on Trips). Throws when the link no longer works.
    public func followJourney(token: String) async throws {
        let _: FollowingAnswer = try await send("PUT", ["following", token])
    }

    public func unfollowJourney(token: String) async throws {
        try await perform("DELETE", ["following", token])
    }

    /// The shared journeys this phone follows that still work.
    public func followedJourneys() async throws -> [SharedJourney] {
        try await get(["following"])
    }
}
