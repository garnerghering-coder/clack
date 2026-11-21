//
//  Presence.swift
//  Clack
//

import Foundation
import os

/// Whether the app is in front, for the network to follow (build 90). iOS freezes an app a few seconds after it leaves
/// the screen, and the connections it held die while it's frozen; on its return every request still open failed at
/// once, the strip blamed the server and search and Explore waited out 15 s timeouts on the dead connection. So:
/// the live streams close when the app leaves (`EventStream.events`) and open again when it comes back, the polls
/// wait (`RetryWake.pause`), a request the freeze cut short says nothing about the server (`epoch`), and after a while
/// away the next requests go on new connections (`ConnectionState`).
///
/// In front until told otherwise: the widgets, the intents and the tests never say.
public nonisolated final class AppPresence: Sendable {
    public static let shared = AppPresence()

    private struct State {
        var inFront = true
        /// Goes up each time the app leaves the screen.
        var epoch = 0
        var leftAt: Date?
        var waiters: [UUID: CheckedContinuation<Void, Never>] = [:]
        var onLeave: [UUID: @Sendable () -> Void] = [:]
    }

    private let state = OSAllocatedUnfairLock(initialState: State())

    public init() {}

    public var inFront: Bool { state.withLock { $0.inFront } }

    /// Changes each time the app leaves the screen: a request that began under another epoch was frozen on the way.
    public var epoch: Int { state.withLock { $0.epoch } }

    /// The app left the screen: open streams close now (while there is time to say so to the server).
    public func left(now: Date = .now) {
        let handlers = state.withLock { s -> [@Sendable () -> Void] in
            guard s.inFront else { return [] }
            s.inFront = false
            s.epoch += 1
            s.leftAt = now
            return Array(s.onLeave.values)
        }
        for handler in handlers { handler() }
    }

    /// The app is in front again. How long it was away, if it had left.
    @discardableResult
    public func returned(now: Date = .now) -> TimeInterval? {
        let (waiters, away) = state.withLock { s -> ([CheckedContinuation<Void, Never>], TimeInterval?) in
            guard !s.inFront else { return ([], nil) }
            s.inFront = true
            let list = Array(s.waiters.values)
            s.waiters = [:]
            return (list, s.leftAt.map { now.timeIntervalSince($0) })
        }
        for waiter in waiters { waiter.resume() }
        return away
    }

    /// Returns when the app is in front (at once if it is), or when the task is cancelled.
    public func untilInFront() async {
        let id = UUID()
        await withTaskCancellationHandler {
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                let resumeNow = state.withLock { s -> Bool in
                    if s.inFront || Task.isCancelled { return true }
                    s.waiters[id] = continuation
                    return false
                }
                if resumeNow { continuation.resume() }
            }
        } onCancel: {
            state.withLock { $0.waiters.removeValue(forKey: id) }?.resume()
        }
    }

    /// Runs `handler` when the app next leaves the screen, until `forget` is called with the returned id.
    public func whenLeaving(_ handler: @escaping @Sendable () -> Void) -> UUID {
        let id = UUID()
        state.withLock { $0.onLeave[id] = handler }
        return id
    }

    public func forget(_ id: UUID) {
        state.withLock { _ = $0.onLeave.removeValue(forKey: id) }
    }
}

/// The sessions the app's requests and streams go on, made new after a while away from the screen or a change of
/// network (build 90). `URLSession.flush` was tried first: its requests still went on the old HTTP/2 connection
/// (Network log, simulator), and a connection that died while the app was frozen is the one to leave behind. A new
/// session can't reuse anything; the old one finishes what it has and is let go.
public nonisolated final class Connections: Sendable {
    public static let shared = Connections()

    private struct Sessions {
        var requests: URLSession
        var streams: URLSession
    }

    private let sessions: OSAllocatedUnfairLock<Sessions>

    public init() {
        sessions = OSAllocatedUnfairLock(initialState: Sessions(requests: Self.makeRequests(), streams: Self.makeStreams()))
    }

    /// Ordinary requests (each sets its own timeout).
    public var requests: URLSession { sessions.withLock { $0.requests } }
    /// The live streams: the request timeout is longer than the server's heartbeat, so a quiet stream isn't cut.
    public var streams: URLSession { sessions.withLock { $0.streams } }

    /// New sessions from here on; the old ones finish their tasks and go.
    public func renew() {
        let old = sessions.withLock { s -> Sessions in
            let old = s
            s = Sessions(requests: Self.makeRequests(), streams: Self.makeStreams())
            return old
        }
        old.requests.finishTasksAndInvalidate()
        old.streams.finishTasksAndInvalidate()
    }

    private static func makeRequests() -> URLSession {
        URLSession(configuration: .default)
    }

    private static func makeStreams() -> URLSession {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 120
        configuration.timeoutIntervalForResource = .infinity
        return URLSession(configuration: configuration)
    }
}

/// The last few hundred requests and connection events, for the test tools' Network log (Xcode and TestFlight builds
/// only; nothing is kept unless `enabled`). Each request says how its connection went (reused or new, DNS, connect,
/// TLS, first byte), so a stale connection or a slow server can be told apart on the phone itself.
public nonisolated final class NetworkLog: Sendable {
    public static let shared = NetworkLog()

    public struct Entry: Sendable, Identifiable, Equatable {
        public let id: UUID
        public let at: Date
        public var text: String
        /// How the connection went, when URLSession said (added when its metrics arrive).
        public var connection: String?
    }

    private struct State {
        var enabled = false
        var entries: [Entry] = []
        /// Metrics that came before their request's entry.
        var pending: [UUID: String] = [:]
    }

    private let state = OSAllocatedUnfairLock(initialState: State())
    public static let limit = 300

    public init() {}

    public var enabled: Bool {
        get { state.withLock { $0.enabled } }
        set { state.withLock { $0.enabled = newValue } }
    }

    public var entries: [Entry] { state.withLock { $0.entries } }

    public func clear() { state.withLock { $0.entries = []; $0.pending = [:] } }

    /// Adds a line (a request's outcome, the app leaving, a new connection asked for).
    public func note(_ text: String, id: UUID = UUID(), at: Date = .now) {
        state.withLock { s in
            guard s.enabled else { return }
            let connection = s.pending.removeValue(forKey: id)
            s.entries.append(Entry(id: id, at: at, text: text, connection: connection))
            if s.entries.count > Self.limit { s.entries.removeFirst(s.entries.count - Self.limit) }
        }
    }

    /// A request's connection metrics, in either order with its line.
    public func attach(_ id: UUID, connection: String) {
        state.withLock { s in
            guard s.enabled else { return }
            if let index = s.entries.lastIndex(where: { $0.id == id }) {
                s.entries[index].connection = connection
            } else {
                s.pending[id] = connection
                if s.pending.count > 50 { s.pending = [:] }
            }
        }
    }

    /// Everything as text, oldest first (Copy in the log).
    public func text() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "HH:mm:ss.SSS"
        return entries.map { entry in
            let line = formatter.string(from: entry.at) + "  " + entry.text
            return entry.connection.map { line + "\n    " + $0 } ?? line
        }.joined(separator: "\n")
    }

    /// One request's connection, in a line: reused or new, the protocol, and the time each step took.
    public static func describe(_ metrics: URLSessionTaskMetrics) -> String {
        // Only what went over the network (a look in the local cache is a transaction too).
        let loads = metrics.transactionMetrics.filter { $0.resourceFetchType == .networkLoad }
        guard let t = loads.last else { return "from the cache" }
        func ms(_ from: Date?, _ to: Date?) -> String? {
            guard let from, let to else { return nil }
            return String(Int((to.timeIntervalSince(from) * 1000).rounded()))
        }
        var parts = [t.isReusedConnection ? "reused" : "new", t.networkProtocolName ?? "?"]
        if let v = ms(t.domainLookupStartDate, t.domainLookupEndDate) { parts.append("dns \(v)") }
        if let v = ms(t.connectStartDate, t.connectEndDate) { parts.append("connect \(v)") }
        if let v = ms(t.secureConnectionStartDate, t.secureConnectionEndDate) { parts.append("tls \(v)") }
        if let v = ms(t.requestStartDate, t.responseStartDate) { parts.append("first byte \(v)") }
        if let v = ms(t.fetchStartDate, t.responseEndDate) { parts.append("total \(v) ms") }
        if loads.count > 1 { parts.append("\(loads.count) tries") }
        if t.isCellular { parts.append("cellular") }
        if t.isConstrained { parts.append("low data") }
        return parts.joined(separator: ", ")
    }
}

/// Hands one task's metrics to the Network log.
nonisolated final class MetricsCatcher: NSObject, URLSessionTaskDelegate, Sendable {
    let id: UUID

    init(id: UUID) { self.id = id }

    func urlSession(_ session: URLSession, task: URLSessionTask, didFinishCollecting metrics: URLSessionTaskMetrics) {
        NetworkLog.shared.attach(id, connection: NetworkLog.describe(metrics))
    }
}
