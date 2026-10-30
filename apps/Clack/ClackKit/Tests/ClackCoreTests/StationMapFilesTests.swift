//
//  StationMapFilesTests.swift
//  ClackTests
//

import Foundation
import Testing
@testable import ClackCore

/// Every station map the server serves must decode in the app: one field the model can't read makes the whole map
/// "There's no map for this station yet" (2026-10-30: 25 maps were unreadable for a source without a type).
struct StationMapFilesTests {
    @Test func everyCommittedStationMapDecodes() throws {
        let dir = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("../../../../../data/stations").standardized
        let files = try FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil).filter { $0.pathExtension == "json" }
        #expect(files.count > 50)
        var failed: [String] = []
        for f in files {
            do { _ = try JSONDecoder().decode(StationMap.self, from: Data(contentsOf: f)) } catch { failed.append("\(f.lastPathComponent): \(error)".prefix(240).description) }
        }
        #expect(failed.isEmpty, "\(failed.count) maps don't decode: \(failed.prefix(5).joined(separator: " | "))")
    }
}
