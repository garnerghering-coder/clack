//
//  StationMapStoreTests.swift
//  ClackTests
//

import Foundation
import Testing
@testable import ClackCore

struct StationMapStoreTests {
    @Test func keepsAMapWithItsETagAndForgetsIt() async throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("maps-\(UUID().uuidString)")
        let store = StationMapStore(directory: dir)
        #expect(await store.read("fi:HKI") == nil)
        await store.write("fi:HKI", data: Data("{}".utf8), etag: "\"abc-1\"")
        let kept = try #require(await store.read("fi:HKI"))
        #expect(kept.data == Data("{}".utf8))
        #expect(kept.etag == "\"abc-1\"")
        #expect(await store.keptIds() == ["fi_HKI"])
        await store.remove("fi:HKI")
        #expect(await store.read("fi:HKI") == nil)
        try? FileManager.default.removeItem(at: dir)
    }
}
