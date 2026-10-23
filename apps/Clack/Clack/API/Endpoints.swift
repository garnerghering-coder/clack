//
//  Endpoints.swift
//  Clack
//

import Foundation

/// The server's endpoints the app uses, one function each (docs/swift-port/API.md). Ids go in the path as-is:
/// `APIClient.url` percent-encodes every segment.
extension APIClient {
    func settings() async throws -> Settings { try await get(["settings"]) }
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
}
