//
//  DirectionsTests.swift
//  ClackTests
//

import Foundation
import Testing
@testable import ClackCore

struct DirectionsTests {
    @Test func appleMapsGoesToTheStation() {
        #expect(Directions.appleMaps(lat: 59.330231, lon: 18.059196)?.absoluteString == "https://maps.apple.com/?daddr=59.330231,18.059196")
    }

    @Test func noPlaceNoLink() {
        #expect(Directions.appleMaps(lat: 0, lon: 0) == nil)
        #expect(Directions.appleMaps(lat: .nan, lon: 18) == nil)
        #expect(Directions.appleMaps(lat: 91, lon: 18) == nil)
    }

    @Test func theExportHasTheServersName() {
        // 23:30 UTC on the 24th is already the 25th in Stockholm; the file is named by the UTC day, as the server does.
        let late = Date(timeIntervalSince1970: (Instant.parse("2026-10-24T23:30:00Z")?.timeIntervalSince1970 ?? 0))
        #expect(DataExport.fileName(now: late) == "clack-export-2026-10-24.json")
    }
}
