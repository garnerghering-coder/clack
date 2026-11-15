//
//  OfflineCacheTests.swift
//  ClackTests
//

import Foundation
import Testing
@testable import ClackCore

/// Answers requests from a closure, so the client can be tested without a network.
final class StubProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var handler: (@Sendable (URLRequest) throws -> (Int, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        do {
            guard let handler = StubProtocol.handler else { throw URLError(.notConnectedToInternet) }
            let (status, data) = try handler(request)
            let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}

    static var session: URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubProtocol.self]
        return URLSession(configuration: configuration)
    }
}

private func temporaryDirectory() -> URL {
    FileManager.default.temporaryDirectory.appendingPathComponent("clack-test-\(UUID().uuidString)", isDirectory: true)
}

struct OfflineCacheTests {
    @Test func keepsTheSamePathsTheWebKeeps() {
        for path in ["/legs", "/legs/abc", "/journeys/j-1", "/operators", "/train-types", "/settings", "/amenities", "/stations/740000001", "/stations/740000001/map", "/passport", "/passport?year=all&commuter=true", "/map/status"] {
            #expect(OfflineCache.isCacheable(path), "\(path)")
        }
        for path in ["/legs/abc/risk", "/legs/abc/progress", "/stations/1/board", "/follows", "/search", "/live/trains"] {
            #expect(!OfflineCache.isCacheable(path), "\(path)")
        }
    }

    @Test func storesAndReadsBack() async {
        let cache = OfflineCache(directory: temporaryDirectory())
        await cache.store("/legs", Data("[1]".utf8))
        #expect(await cache.read("/legs") == Data("[1]".utf8))
        #expect(await cache.read("/operators") == nil)
    }

    @Test func neverStoresWhatTheWebWouldNot() async {
        let cache = OfflineCache(directory: temporaryDirectory())
        await cache.store("/follows", Data("x".utf8))
        await cache.store("/search?q=a", Data("x".utf8))
        #expect(await cache.read("/follows") == nil)
        #expect(await cache.paths().isEmpty)
    }

    @Test func dropsTheOldestBeyondSixtyEntries() async {
        let cache = OfflineCache(directory: temporaryDirectory())
        for i in 0..<65 { await cache.store("/legs/\(i)", Data("\(i)".utf8)) }
        let paths = await cache.paths()
        #expect(paths.count == 60)
        #expect(paths.first == "/legs/5")
        #expect(await cache.read("/legs/0") == nil)
        #expect(await cache.read("/legs/64") == Data("64".utf8))
    }

    @Test func readingDoesNotReorderButStoringAgainRefreshes() async {
        let cache = OfflineCache(directory: temporaryDirectory())
        await cache.store("/legs/a", Data("1".utf8))
        await cache.store("/legs/b", Data("2".utf8))
        await cache.store("/legs/a", Data("3".utf8))
        #expect(await cache.paths() == ["/legs/b", "/legs/a"])
        #expect(await cache.read("/legs/a") == Data("3".utf8))
    }

    @Test func survivesARestartAndCanBeCleared() async {
        let directory = temporaryDirectory()
        let first = OfflineCache(directory: directory)
        await first.store("/settings", Data("{}".utf8))
        let second = OfflineCache(directory: directory)
        #expect(await second.paths() == ["/settings"])
        #expect(await second.read("/settings") == Data("{}".utf8))
        await second.clear()
        #expect(await second.paths().isEmpty)
        #expect(await second.read("/settings") == nil)
    }
}

@Suite(.serialized)
struct APIClientOfflineTests {
    private let userID = "11111111-1111-4111-8111-111111111111"

    private func client(cache: OfflineCache?, reach: (@Sendable (Reach) -> Void)? = nil) -> APIClient {
        APIClient(base: URL(string: "http://localhost:3001")!, userID: userID, session: StubProtocol.session, cache: cache, reachability: reach)
    }

    @Test func sendsThePhoneIdAndOnlyLabelsABodyAsJSON() async throws {
        let seen = Box<URLRequest?>(nil)
        StubProtocol.handler = { request in
            seen.value = request
            return (200, Data("[]".utf8))
        }
        let _: [Leg] = try await client(cache: nil).get(["legs"])
        #expect(seen.value?.value(forHTTPHeaderField: "X-Clack-User") == userID)
        #expect(seen.value?.value(forHTTPHeaderField: "Content-Type") == nil)
        #expect(seen.value?.timeoutInterval == 15)
    }

    @Test func servesTheKeptCopyWhenTheServerCannotBeReached() async throws {
        let cache = OfflineCache(directory: temporaryDirectory())
        let reached = Box<[Bool]>([])
        let c = client(cache: cache) { reached.value.append($0.reached) }
        StubProtocol.handler = { _ in (200, Data("[]".utf8)) }
        let online: [Leg] = try await c.get(["legs"])
        #expect(online.isEmpty)
        StubProtocol.handler = { _ in throw URLError(.notConnectedToInternet) }
        let offline: [Leg] = try await c.get(["legs"])
        #expect(offline.isEmpty)
        #expect(reached.value == [true, false])
    }

    @Test func failsWhenThereIsNothingKept() async {
        let c = client(cache: OfflineCache(directory: temporaryDirectory()))
        StubProtocol.handler = { _ in throw URLError(.timedOut) }
        // Asked once here: the retries are RetryTests'.
        await #expect(throws: URLError.self) { let _: [Leg] = try await RetryPolicy.none.applying { try await c.get(["legs"]) } }
    }

    @Test func anHTTPErrorIsNotServedFromTheCacheAndMarksTheServerReachable() async throws {
        let cache = OfflineCache(directory: temporaryDirectory())
        await cache.store("/legs", Data("[]".utf8))
        let reached = Box<[Bool]>([])
        let c = client(cache: cache) { reached.value.append($0.reached) }
        StubProtocol.handler = { _ in (500, Data(#"{"statusCode":500,"error":"Internal Server Error","message":"upstream"}"#.utf8)) }
        do {
            let _: [Leg] = try await c.get(["legs"])
            Issue.record("expected an APIError")
        } catch let error as APIError {
            #expect(error.status == 500)
            #expect(error.message == "Internal Server Error")
        }
        #expect(reached.value == [true])
    }

    @Test func decodesTheDuplicateOfFieldOfA409() async {
        StubProtocol.handler = { _ in (409, Data(#"{"error":"You already added this train on this date","duplicateOf":"abc"}"#.utf8)) }
        do {
            _ = try await client(cache: nil).request("POST", ["legs"], body: ["tripKey": "k"])
            Issue.record("expected an APIError")
        } catch let error as APIError {
            #expect(error.status == 409)
            #expect(error.duplicateOf == "abc")
        } catch {
            Issue.record("wrong error \(error)")
        }
    }

    @Test func aBodyGetsAJSONContentTypeAndNoBodyGetsNone() async throws {
        let seen = Box<[URLRequest]>([])
        StubProtocol.handler = { request in
            seen.value.append(request)
            return (204, Data())
        }
        let c = client(cache: nil)
        try await c.perform("POST", ["legs", "a", "refresh"])
        try await c.perform("POST", ["legs", "a", "ride"], body: ["answer": "yes"])
        #expect(seen.value[0].value(forHTTPHeaderField: "Content-Type") == nil)
        #expect(seen.value[1].value(forHTTPHeaderField: "Content-Type") == "application/json")
    }

    // MARK: retries

    @Test func aGetIsAskedAgainWhenTheServerIsDownAndTheScreenHearsIt() async throws {
        let calls = Box(0)
        StubProtocol.handler = { _ in
            calls.value += 1
            return calls.value == 1 ? (503, Data()) : (200, Data("[]".utf8))
        }
        let heard = Box<[RetryStatus]>([])
        let legs: [Leg] = try await observingRetries({ heard.value.append($0) }) { try await client(cache: nil).get(["legs"]) }
        #expect(legs.isEmpty)
        #expect(calls.value == 2)
        guard case .retrying(1, _, .serverDown) = heard.value.first else {
            Issue.record("expected a retry, heard \(heard.value)")
            return
        }
        #expect(heard.value.last == .idle)
    }

    @Test func aRefusalIsNotAskedAgain() async {
        let calls = Box(0)
        StubProtocol.handler = { _ in
            calls.value += 1
            return (404, Data(#"{"error":"Not found"}"#.utf8))
        }
        await #expect(throws: APIError.self) { let _: [Leg] = try await client(cache: nil).get(["legs"]) }
        #expect(calls.value == 1)
    }

    @Test func aWriteIsAskedOnceAndCarriesAnIdempotencyKey() async {
        let seen = Box<[URLRequest]>([])
        StubProtocol.handler = { request in
            seen.value.append(request)
            return (503, Data())
        }
        await #expect(throws: APIError.self) { _ = try await client(cache: nil).request("POST", ["legs"], body: ["tripKey": "k"]) }
        #expect(seen.value.count == 1)
        let key = seen.value.first?.value(forHTTPHeaderField: "Idempotency-Key")
        #expect(key.flatMap(UUID.init(uuidString:)) != nil)
    }

    @Test func aWriteAskedAgainKeepsItsIdempotencyKey() async throws {
        let seen = Box<[URLRequest]>([])
        StubProtocol.handler = { request in
            seen.value.append(request)
            return seen.value.count == 1 ? (503, Data()) : (204, Data())
        }
        _ = try await client(cache: nil).request("POST", ["legs", "a", "refresh"], policy: RetryPolicy(tries: 2))
        #expect(seen.value.count == 2)
        let keys = seen.value.map { $0.value(forHTTPHeaderField: "Idempotency-Key") }
        #expect(keys[0] != nil && keys[0] == keys[1])
    }
}

final class Box<T>: @unchecked Sendable {
    private let lock = NSLock()
    private var stored: T

    init(_ value: T) { stored = value }

    var value: T {
        get { lock.lock(); defer { lock.unlock() }; return stored }
        set { lock.lock(); defer { lock.unlock() }; stored = newValue }
    }
}
