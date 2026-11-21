//
//  EventStream.swift
//  Clack
//

import Foundation

/// One Server-Sent Event: its name (`event:`) and data (`data:` lines joined by newlines).
public nonisolated struct SSEEvent: Equatable, Sendable {
    public var name: String
    public var data: String

    public init(name: String, data: String) {
        self.name = name
        self.data = data
    }

    /// The name `EventStream.events` gives the server's `retry:` field, passed on as an event of its own so the
    /// listener can wait that long before reconnecting. Not a name the server sends.
    public static let retryName = "clack.retry"

    /// The reconnection wait the server asked for, in seconds, when this is its `retry:` field.
    public var retrySeconds: TimeInterval? {
        guard name == Self.retryName, let ms = Double(data) else { return nil }
        return ms / 1000
    }
}

/// Reads the text/event-stream format a line at a time: `event:` and `data:` fields, `:` comment lines (the server's
/// heartbeat) skipped, an event dispatched on a blank line (docs/SWIFT_PORT.md B4).
public nonisolated struct SSEParser: Sendable {
    private var name = ""
    private var data: [String] = []
    /// The last `retry:` the server sent (milliseconds), if any.
    public private(set) var retry: Int?

    /// Feeds one line (without its newline); returns an event when the line ends one.
    public mutating func feed(_ rawLine: String) -> SSEEvent? {
        let line = rawLine.hasSuffix("\r") ? String(rawLine.dropLast()) : rawLine
        if line.isEmpty {
            defer {
                name = ""
                data = []
            }
            guard !data.isEmpty else { return nil }
            return SSEEvent(name: name.isEmpty ? "message" : name, data: data.joined(separator: "\n"))
        }
        if line.hasPrefix(":") { return nil }
        let field: String
        var value: String
        if let colon = line.firstIndex(of: ":") {
            field = String(line[..<colon])
            value = String(line[line.index(after: colon)...])
            if value.hasPrefix(" ") { value.removeFirst() }
        } else {
            field = line
            value = ""
        }
        switch field {
        case "event": name = value
        case "data": data.append(value)
        // Only digits count (the spec ignores anything else).
        case "retry": if !value.isEmpty, value.allSatisfy(\.isASCII), value.allSatisfy(\.isNumber), let ms = Int(value) { retry = ms }
        default: break // id: the server sends the full state each time, so nothing is replayed.
        }
        return nil
    }
}

public nonisolated enum EventStream {
    /// Opens a stream and yields its events until it ends or fails. The server's `retry:` comes through as an event
    /// named `SSEEvent.retryName`; a refusal as an `APIError` (so a 429 or 503 is told from no connection).
    ///
    /// While the app is away from the screen the stream is closed, and it opens again when the app is back
    /// (`AppPresence`): the reader sees one stream, without a failure, and the server sends its full state again on
    /// the new connection.
    public static func events(
        url: URL, userID: String, session: URLSession? = nil, presence: AppPresence = .shared
    ) -> AsyncThrowingStream<SSEEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    while true {
                        await presence.untilInFront()
                        try Task.checkCancellation()
                        let epoch = presence.epoch
                        let connection = Task { try await read(url: url, userID: userID, session: session ?? Connections.shared.streams, into: continuation) }
                        let leaving = presence.whenLeaving { connection.cancel() }
                        // Left between reading the epoch and listening for it.
                        if presence.epoch != epoch { connection.cancel() }
                        let ended = await withTaskCancellationHandler { await connection.result } onCancel: { connection.cancel() }
                        presence.forget(leaving)
                        try Task.checkCancellation()
                        // The app left (or was frozen with it open): open again once it's back.
                        if presence.epoch != epoch {
                            let line = url.path + ": closed while the app was away"
                            NetworkLog.shared.note(line)
                            continue
                        }
                        try ended.get()
                        break
                    }
                    continuation.finish()
                } catch {
                    if NetworkLog.shared.enabled, !(error is CancellationError) {
                        NetworkLog.shared.note(url.path + " stream failed: " + String(describing: error))
                    }
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    /// One connection: its events, until the server ends it or it fails.
    private static func read(
        url: URL, userID: String, session: URLSession, into continuation: AsyncThrowingStream<SSEEvent, Error>.Continuation
    ) async throws {
        var request = URLRequest(url: url)
        request.setValue(userID, forHTTPHeaderField: "X-Clack-User")
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 120
        let log = NetworkLog.shared.enabled ? UUID() : nil
        let (bytes, response) = try await session.bytes(for: request, delegate: log.map { MetricsCatcher(id: $0) })
        guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        if let log { NetworkLog.shared.note("stream \(url.path) opened → \(http.statusCode)", id: log) }
        guard (200..<300).contains(http.statusCode) else {
            let header = http.value(forHTTPHeaderField: "Retry-After")
            throw APIError(
                status: http.statusCode, message: "HTTP \(http.statusCode)", duplicateOf: nil,
                retryAfter: APIError.retryAfter(header: header, message: nil)
            )
        }
        var parser = SSEParser()
        var retry: Int?
        // Split on newlines ourselves: `bytes.lines` skips the empty lines that end an event.
        var line: [UInt8] = []
        for try await byte in bytes {
            if byte == 0x0A {
                if let event = parser.feed(String(decoding: line, as: UTF8.self)) { continuation.yield(event) }
                if parser.retry != retry, let ms = parser.retry {
                    retry = ms
                    continuation.yield(SSEEvent(name: SSEEvent.retryName, data: String(ms)))
                }
                line.removeAll(keepingCapacity: true)
            } else {
                line.append(byte)
            }
        }
    }
}

extension EventStream {
    /// An event's data decoded off the calling actor (a full live-map snapshot is a large JSON document and the callers
    /// are on the main actor); nil when it doesn't decode. The caller publishes the result.
    @concurrent
    public static func decode<T: Decodable & Sendable>(_ type: T.Type, from event: SSEEvent) async -> T? {
        try? JSONDecoder().decode(type, from: Data(event.data.utf8))
    }
}

/// One shared connection to `GET /api/live/stream` while at least one screen listens (apps/web/src/live.ts): it opens
/// with the first listener, closes after the last, and reconnects after a drop with backoff (1 s, 2 s, 4 s … 30 s,
/// never sooner than the server's `retry:`; at once when the connection comes back). The server sends the full live
/// state every tick, so nothing needs replaying.
@MainActor
public final class LiveHub {
    private var listeners: [UUID: AsyncStream<LiveUpdate>.Continuation] = [:]
    private var task: Task<Void, Never>?
    private let open: @Sendable () -> AsyncThrowingStream<SSEEvent, Error>
    /// A fixed wait in place of the backoff (tests).
    private let retryDelay: Duration?

    public init(retryDelay: Duration? = nil, open: @escaping @Sendable () -> AsyncThrowingStream<SSEEvent, Error>) {
        self.open = open
        self.retryDelay = retryDelay
    }

    public convenience init(client: APIClient) {
        let url = client.url(["live", "stream"])
        let userID = client.userID
        self.init { EventStream.events(url: url, userID: userID) }
    }

    /// Every live update while the stream is being iterated.
    public func updates() -> AsyncStream<LiveUpdate> {
        let id = UUID()
        let (stream, continuation) = AsyncStream<LiveUpdate>.makeStream(bufferingPolicy: .bufferingNewest(32))
        listeners[id] = continuation
        continuation.onTermination = { [weak self] _ in
            Task { @MainActor [weak self] in self?.remove(id) }
        }
        connectIfNeeded()
        return stream
    }

    public var listenerCount: Int { listeners.count }

    private func remove(_ id: UUID) {
        listeners[id] = nil
        if listeners.isEmpty {
            task?.cancel()
            task = nil
        }
    }

    private func connectIfNeeded() {
        guard task == nil else { return }
        task = Task { [weak self] in
            var retrier = Retrier(.stream)
            while !Task.isCancelled {
                guard let self else { return }
                var failure: any Error = URLError(.networkConnectionLost)
                do {
                    for try await event in self.open() {
                        if let seconds = event.retrySeconds { retrier.serverHint = seconds }
                        guard event.name == "live" else { continue }
                        retrier.succeeded()
                        if let update = await EventStream.decode(LiveUpdate.self, from: event) {
                            self.deliver(update)
                        }
                    }
                } catch {
                    failure = error
                }
                if Task.isCancelled { return }
                // A stream that ended cleanly is reconnected like a dropped one; after a refusal, only at the slowest pace.
                let delay = retrier.failed(failure) ?? retrier.policy.cap
                if let retryDelay {
                    try? await Task.sleep(for: retryDelay)
                } else {
                    _ = try? await RetryWake.shared.sleep(delay)
                }
            }
        }
    }

    private func deliver(_ update: LiveUpdate) {
        for continuation in listeners.values { continuation.yield(update) }
    }
}
