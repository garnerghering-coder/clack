//
//  StationDirectory.swift
//  Clack
//

import ClackCore
import Foundation

/// Station information and maps, fetched once per station for the whole session (Connection.tsx `useStationMap`).
/// Maps are also kept on the phone (`StationMapStore`) and checked with their ETag, so a station you have opened, or
/// one an upcoming journey changes at, opens without a connection. A station without a map is remembered as nothing;
/// a failed fetch is not remembered when there is no kept copy, so the next look tries again.
@MainActor
final class StationDirectory {
    private let client: APIClient
    private let store: StationMapStore
    private var infos: [String: Task<StationInfo?, Never>] = [:]
    private var maps: [String: Task<StationMap?, Never>] = [:]

    init(client: APIClient, store: StationMapStore = StationMapStore()) {
        self.client = client
        self.store = store
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
        if let task = maps[id] { return await task.value }
        let (client, store) = (client, store)
        let info = await info(id)
        // The station page says it has no map: none (a kept copy of one since taken away goes too).
        if let info, !info.hasMap {
            await store.remove(id)
            return nil
        }
        let task = Task<StationMap?, Never> { await Self.load(id, client: client, store: store) }
        maps[id] = task
        let map = await task.value
        if map == nil { maps[id] = nil }
        return map
    }

    /// Fetches the map when it changed, else uses the kept copy; the kept copy too when the server can't be reached.
    private nonisolated static func load(_ id: String, client: APIClient, store: StationMapStore) async -> StationMap? {
        let kept = await store.read(id)
        let decode = { (data: Data) in try? JSONDecoder().decode(StationMap.self, from: data) }
        do {
            switch try await client.stationMapConditional(id, etag: kept?.etag) {
            case .notModified:
                return kept.flatMap { decode($0.data) }
            case .fresh(let data, let etag):
                guard let map = decode(data) else { return kept.flatMap { decode($0.data) } }
                await store.write(id, data: data, etag: etag)
                return map
            case .none:
                await store.remove(id)
                return nil
            }
        } catch {
            return kept.flatMap { decode($0.data) }
        }
    }

    /// Fetches and keeps the maps of these stations (the change stations and destinations of upcoming journeys), so
    /// they open offline. Already-kept ones cost a 304.
    func prefetch(_ ids: [String]) async {
        for id in Set(ids) { _ = await map(id) }
    }

    /// Forgets everything (after "Delete my data").
    func reset() {
        infos = [:]
        maps = [:]
        let store = store
        Task { await store.removeAll() }
    }
}
