//
//  SavedCopy.swift
//  Clack
//

import ClackCore
import Foundation

/// Show what the phone kept first, then refresh (polish pass 1, owner 2026-11-14: "give the user stuff to have while
/// the rest loads in"). This only reads the kept copies `APIClient` already writes; it doesn't change how the app talks
/// to the server.
extension APIClient {
    /// The kept copy of a GET, decoded off the main thread, without asking the server. Nil when there is none.
    func saved<T: Decodable & Sendable>(_ segments: [String], query: [String: String] = [:]) async -> T? {
        guard let cache else { return nil }
        let path = "/" + segments.joined(separator: "/")
        guard let data = await cache.read(Self.cacheKey(path, query)) else { return nil }
        return await Task.detached(priority: .userInitiated) { try? JSONDecoder().decode(T.self, from: data) }.value
    }
}

/// When each screen's data last came fresh from the server, for "Updated 12 min ago" over a kept copy.
enum SavedAt {
    private static let key = "clack.savedAt"

    /// Notes that `name`'s data just came from the server.
    static func mark(_ name: String, at ms: Double = Date.now.timeIntervalSince1970 * 1000) {
        var all = UserDefaults.standard.dictionary(forKey: key) as? [String: Double] ?? [:]
        all[name] = ms
        UserDefaults.standard.set(all, forKey: key)
    }

    /// When `name`'s data last came from the server, in ms; nil if never.
    static func at(_ name: String) -> Double? {
        (UserDefaults.standard.dictionary(forKey: key) as? [String: Double])?[name]
    }
}
