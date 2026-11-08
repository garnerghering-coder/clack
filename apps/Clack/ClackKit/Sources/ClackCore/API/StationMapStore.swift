//
//  StationMapStore.swift
//  Clack
//

import Foundation

/// Station maps kept on the phone for offline use, in Application Support (not Caches: a map you are about to walk
/// through must not be cleared to make room), one JSON file per station with the server's ETag beside it. A kept map
/// is checked with a conditional GET; an unchanged one costs a 304 and no download.
public actor StationMapStore {
    private let directory: URL

    public init(directory: URL? = nil) {
        let base = directory ?? (FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? FileManager.default.temporaryDirectory)
            .appendingPathComponent("clack-station-maps", isDirectory: true)
        self.directory = base
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
    }

    private func file(_ id: String, _ ext: String) -> URL {
        // Finnish and Norwegian ids carry colons ("fi:HKI", "NSR:StopPlace:337").
        directory.appendingPathComponent("\(id.replacingOccurrences(of: ":", with: "_")).\(ext)")
    }

    /// The kept copy and its ETag, if there is one.
    public func read(_ id: String) -> (data: Data, etag: String?)? {
        guard let data = try? Data(contentsOf: file(id, "json")) else { return nil }
        return (data, try? String(contentsOf: file(id, "etag"), encoding: .utf8))
    }

    public func write(_ id: String, data: Data, etag: String?) {
        try? data.write(to: file(id, "json"), options: .atomic)
        if let etag { try? etag.write(to: file(id, "etag"), atomically: true, encoding: .utf8) } else { try? FileManager.default.removeItem(at: file(id, "etag")) }
    }

    public func remove(_ id: String) {
        try? FileManager.default.removeItem(at: file(id, "json"))
        try? FileManager.default.removeItem(at: file(id, "etag"))
    }

    /// Station ids with a kept map.
    public func keptIds() -> [String] {
        ((try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? []).filter { $0.hasSuffix(".json") }.map { String($0.dropLast(5)) }
    }

    /// Forgets every kept map (after "Delete my data").
    public func removeAll() {
        for name in (try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? [] {
            try? FileManager.default.removeItem(at: directory.appendingPathComponent(name))
        }
    }
}

/// What a conditional GET of a station map gave.
public nonisolated enum ConditionalMap: Sendable {
    /// The kept copy is current (304).
    case notModified
    case fresh(Data, etag: String?)
    /// The station has no map (404).
    case none
}

extension APIClient {
    /// `GET /stations/:id/map` with `If-None-Match` when a copy is kept. Throws when the server can't be reached.
    public func stationMapConditional(_ id: String, etag: String?) async throws -> ConditionalMap {
        var request = URLRequest(url: url(["stations", id, "map"]))
        request.setValue(userID, forHTTPHeaderField: "X-Clack-User")
        request.timeoutInterval = Self.getTimeout
        // The 304 must reach this code: URLSession's own cache would answer it with its copy, or not at all.
        request.cachePolicy = .reloadIgnoringLocalCacheData
        if let etag { request.setValue(etag, forHTTPHeaderField: "If-None-Match") }
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            if (error as? URLError)?.code != .cancelled { reachability?(false) }
            throw error
        }
        reachability?(true)
        guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        switch http.statusCode {
        case 304: return .notModified
        case 404: return .none
        case 200..<300: return .fresh(data, etag: http.value(forHTTPHeaderField: "ETag"))
        default: throw APIError(status: http.statusCode, message: "HTTP \(http.statusCode)", duplicateOf: nil)
        }
    }
}
