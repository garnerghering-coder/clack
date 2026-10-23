//
//  OfflineCache.swift
//  Clack
//

import Foundation

/// JSON copies of the same GET responses the web keeps, in the Caches folder, so the app still shows its trips when
/// the server can't be reached (docs/SWIFT_PORT.md B4; `apps/web/src/offline.ts`). At most 60 entries, the oldest
/// dropped first. Live data, boards, search, the Passport and follows are never kept.
actor OfflineCache {
    static let maxEntries = 60

    private let directory: URL
    /// Paths, most recently used last.
    private var index: [String]

    init(directory: URL? = nil) {
        let base = directory ?? (FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first ?? FileManager.default.temporaryDirectory)
            .appendingPathComponent("clack-offline", isDirectory: true)
        self.directory = base
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        index = (try? JSONDecoder().decode([String].self, from: Data(contentsOf: base.appendingPathComponent("index.json")))) ?? []
    }

    /// Whether a response is worth keeping: the paths under `/api` (without the query) the web keeps:
    /// `/legs`, `/legs/:id`, `/journeys/:id`, `/operators`, `/train-types`, `/settings`, `/amenities`, `/stations/:id`
    /// and `/stations/:id/map`.
    nonisolated static func isCacheable(_ path: String) -> Bool {
        let patterns = [
            "^/legs$", "^/legs/[^/]+$", "^/journeys/[^/]+$", "^/operators$", "^/train-types$", "^/settings$",
            "^/amenities$", "^/stations/[^/?]+$", "^/stations/[^/]+/map$",
        ]
        return patterns.contains { path.range(of: $0, options: .regularExpression) != nil }
    }

    private func file(for path: String) -> URL {
        // A stable, filesystem-safe name for the path.
        let name = path.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? String(path.hashValue)
        return directory.appendingPathComponent("\(name).json")
    }

    private func saveIndex() {
        if let data = try? JSONEncoder().encode(index) {
            try? data.write(to: directory.appendingPathComponent("index.json"), options: .atomic)
        }
    }

    func store(_ path: String, _ data: Data) {
        guard Self.isCacheable(path) else { return }
        do {
            try data.write(to: file(for: path), options: .atomic)
        } catch {
            return
        }
        index.removeAll { $0 == path }
        index.append(path)
        while index.count > Self.maxEntries {
            let oldest = index.removeFirst()
            try? FileManager.default.removeItem(at: file(for: oldest))
        }
        saveIndex()
    }

    func read(_ path: String) -> Data? {
        guard Self.isCacheable(path), let data = try? Data(contentsOf: file(for: path)) else { return nil }
        return data
    }

    /// The paths kept, oldest first.
    func paths() -> [String] { index }

    /// Forgets everything ("Delete my data").
    func clear() {
        try? FileManager.default.removeItem(at: directory)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        index = []
    }
}
