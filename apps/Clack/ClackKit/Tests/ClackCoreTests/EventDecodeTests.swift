//
//  EventDecodeTests.swift
//  ClackTests
//

import Foundation
import Testing
@testable import ClackCore

/// Records which thread it was decoded on.
private struct WhereDecoded: Decodable, Sendable {
    let onMain: Bool
    init(from decoder: Decoder) throws {
        onMain = Thread.isMainThread
    }
}

struct EventDecodeTests {
    @MainActor @Test func decodesOffTheMainThread() async throws {
        let decoded = await EventStream.decode(WhereDecoded.self, from: SSEEvent(name: "x", data: "{}"))
        #expect(try #require(decoded).onMain == false)
    }

    @Test func badDataIsNil() async {
        #expect(await EventStream.decode(LiveUpdate.self, from: SSEEvent(name: "live", data: "not json")) == nil)
    }
}
