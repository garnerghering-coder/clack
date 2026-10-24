//
//  StationDirectory.swift
//  Clack
//

import ClackCore
import Foundation

/// Station information and maps, fetched once per station for the whole session (Connection.tsx `useStationMap`).
/// A station without a map, or a fetch that failed, is remembered as nothing.
@MainActor
final class StationDirectory {
    private let client: APIClient
    private var infos: [String: Task<StationInfo?, Never>] = [:]
    private var maps: [String: Task<StationMap?, Never>] = [:]

    init(client: APIClient) {
        self.client = client
    }

    func info(_ id: String) async -> StationInfo? {
        if let task = infos[id] { return await task.value }
        let client = client
        let task = Task<StationInfo?, Never> { try? await client.station(id) }
        infos[id] = task
        return await task.value
    }

    /// A station was favourited or un-favourited: the kept details change with it, so opening it again shows the star
    /// as it is now and not as it was when the details were first fetched.
    func setFavorite(_ id: String, _ on: Bool) async {
        guard var known = await info(id) else { return }
        known.favorite = on
        let updated = known
        infos[id] = Task { updated }
    }

    /// The station's map, or nil when it has none.
    func map(_ id: String) async -> StationMap? {
        guard let info = await info(id), info.hasMap else { return nil }
        if let task = maps[id] { return await task.value }
        let client = client
        let task = Task<StationMap?, Never> { try? await client.stationMap(id) }
        maps[id] = task
        return await task.value
    }

    /// Forgets everything (after "Delete my data").
    func reset() {
        infos = [:]
        maps = [:]
    }
}
