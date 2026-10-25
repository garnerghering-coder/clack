//
//  Directions.swift
//  Clack
//

import Foundation

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
