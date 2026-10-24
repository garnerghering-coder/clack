//
//  Directions.swift
//  Clack
//

import Foundation

/// "Directions to Stockholm C" on a trip still ahead: Apple Maps with the station you get on at as the destination
/// (`maps.apple.com/?daddr=lat,lon`), from wherever you are. Maps picks how you travel; Clack sends no position.
public nonisolated enum Directions {
    public static func appleMaps(lat: Double, lon: Double) -> URL? {
        guard lat.isFinite, lon.isFinite, (-90...90).contains(lat), (-180...180).contains(lon), !(lat == 0 && lon == 0) else { return nil }
        var c = URLComponents()
        c.scheme = "https"
        c.host = "maps.apple.com"
        c.path = "/"
        c.queryItems = [URLQueryItem(name: "daddr", value: "\(coordinate(lat)),\(coordinate(lon))")]
        return c.url
    }

    /// Six decimals (about 10 cm), without a locale's comma.
    private static func coordinate(_ value: Double) -> String { String(format: "%.6f", locale: Locale(identifier: "en_US_POSIX"), value) }

    /// The stop the directions lead to: where you get on, on a trip that hasn't left.
    public static func target(_ stops: [LegStop]) -> LegStop? { stops.first { $0.role == .board } }
}

/// "Export my data" (Settings > Your data): the server's `GET /api/me/export`, kept as a file to share.
public nonisolated enum DataExport {
    /// The server's own name for it: `clack-export-YYYY-MM-DD.json`, the date in UTC.
    public static func fileName(now: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = "yyyy-MM-dd"
        return "clack-export-\(f.string(from: now)).json"
    }
}

extension APIClient {
    /// Everything the server keeps for this phone, as the JSON file it sends (`GET /api/me/export`).
    public func exportData() async throws -> Data { try await request("GET", ["me", "export"]) }
}
