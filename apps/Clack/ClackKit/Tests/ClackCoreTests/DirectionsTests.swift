//
//  DirectionsTests.swift
//  ClackTests
//

import Foundation
import Testing
@testable import ClackCore

struct DirectionsTests {
    @Test func theExportHasTheServersName() {
        // 23:30 UTC on the 24th is already the 25th in Stockholm; the file is named by the UTC day, as the server does.
        let late = Date(timeIntervalSince1970: (Instant.parse("2026-10-24T23:30:00Z")?.timeIntervalSince1970 ?? 0))
        #expect(DataExport.fileName(now: late) == "clack-export-2026-10-24.json")
    }
}
