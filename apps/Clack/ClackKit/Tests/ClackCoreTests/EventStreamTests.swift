//
//  EventStreamTests.swift
//  ClackTests
//

import Foundation
import Testing
@testable import ClackCore

struct SSEParserTests {
    private func parse(_ text: String) -> [SSEEvent] {
        var parser = SSEParser()
        return text.components(separatedBy: "\n").compactMap { parser.feed($0) }
    }

    @Test func dispatchesAnEventOnABlankLine() {
        #expect(parse("event: live\ndata: {\"a\":1}\n\n") == [SSEEvent(name: "live", data: "{\"a\":1}")])
    }

    @Test func skipsCommentsAndHeartbeats() {
        #expect(parse(": ping\n\nevent: live\n: another\ndata: x\n\n") == [SSEEvent(name: "live", data: "x")])
    }

    @Test func joinsSeveralDataLinesWithANewline() {
        #expect(parse("data: one\ndata: two\n\n") == [SSEEvent(name: "message", data: "one\ntwo")])
    }

    @Test func ignoresRetryAndIdAndHandlesCarriageReturns() {
        #expect(parse("retry: 5000\r\nid: 7\r\nevent: live\r\ndata: x\r\n\r\n") == [SSEEvent(name: "live", data: "x")])
    }

    @Test func aBlankLineWithNoDataIsNotAnEvent() {
        #expect(parse("event: live\n\n").isEmpty)
    }

    @Test func eachEventStartsFresh() {
        let events = parse("event: a\ndata: 1\n\ndata: 2\n\n")
        #expect(events == [SSEEvent(name: "a", data: "1"), SSEEvent(name: "message", data: "2")])
    }

    @Test func aFieldWithoutAValueAndWithoutASpace() {
        #expect(parse("data:x\n\n") == [SSEEvent(name: "message", data: "x")])
        #expect(parse("data\n\n") == [SSEEvent(name: "message", data: "")])
    }
}

@MainActor
struct LiveHubTests {
    private nonisolated static let update = """
    {"legId":"a","live":{"updatedAt":1792743120000,"status":"en_route","lat":null,"lon":null,"bearing":null,"speedKmh":null,
    "positionSource":null,"positionAt":null,"progress":0.5,"prevStopId":null,"nextStopId":null,"eta":null,"arrivalEta":null,
    "arrivalDelayMin":null,"reportedAt":null},"events":[]}
    """.replacingOccurrences(of: "\n", with: "")

    private func hub(events: [SSEEvent]) -> LiveHub {
        LiveHub(retryDelay: .milliseconds(10)) {
            AsyncThrowingStream { continuation in
                for event in events { continuation.yield(event) }
                // Stays open, like the real stream.
            }
        }
    }

    @Test func deliversEachLiveEventToEveryListenerAndIgnoresTheOthers() async {
        let hub = hub(events: [SSEEvent(name: "hello", data: "x"), SSEEvent(name: "live", data: Self.update)])
        let first = hub.updates()
        let second = hub.updates()
        var a = first.makeAsyncIterator()
        var b = second.makeAsyncIterator()
        let one = await a.next()
        let two = await b.next()
        #expect(one?.legId == "a")
        #expect(two?.legId == "a")
        #expect(one?.live.status == .enRoute)
        #expect(hub.listenerCount == 2)
    }

    @Test func aMessageThatIsNotAnUpdateIsSkippedNotFatal() async {
        let hub = hub(events: [SSEEvent(name: "live", data: "not json"), SSEEvent(name: "live", data: Self.update)])
        var iterator = hub.updates().makeAsyncIterator()
        #expect(await iterator.next()?.legId == "a")
    }

    @Test func reconnectsAfterTheStreamEnds() async {
        let opened = Counter()
        let hub = LiveHub(retryDelay: .milliseconds(10)) {
            opened.increment()
            return AsyncThrowingStream { continuation in
                continuation.yield(SSEEvent(name: "live", data: Self.update))
                continuation.finish()
            }
        }
        var iterator = hub.updates().makeAsyncIterator()
        _ = await iterator.next()
        _ = await iterator.next()
        #expect(opened.value >= 2)
    }

    @Test func closesWhenTheLastListenerLeaves() async throws {
        let hub = hub(events: [])
        var stream: AsyncStream<LiveUpdate>? = hub.updates()
        #expect(hub.listenerCount == 1)
        stream = nil
        _ = stream
        try await Task.sleep(for: .milliseconds(100))
        #expect(hub.listenerCount == 0)
    }
}

private final class Counter: @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0

    func increment() {
        lock.lock()
        count += 1
        lock.unlock()
    }

    var value: Int {
        lock.lock()
        defer { lock.unlock() }
        return count
    }
}
