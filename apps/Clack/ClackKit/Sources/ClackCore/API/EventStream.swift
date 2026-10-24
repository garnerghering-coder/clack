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
}

/// Reads the text/event-stream format a line at a time: `event:` and `data:` fields, `:` comment lines (the server's
/// heartbeat) skipped, an event dispatched on a blank line (docs/SWIFT_PORT.md B4).
public nonisolated struct SSEParser: Sendable {
    private var name = ""
    private var data: [String] = []

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
        default: break // id and retry: the app reconnects after 5 s itself, as the server asks.
        }
        return nil
    }
}

public nonisolated enum EventStream {
    /// Opens a stream and yields its events until it ends or fails. The request timeout is longer than the server's
    /// heartbeat, so a quiet stream isn't cut.
    public static func events(url: URL, userID: String, session: URLSession? = nil) -> AsyncThrowingStream<SSEEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let configuration = URLSessionConfiguration.default
                    configuration.timeoutIntervalForRequest = 120
                    configuration.timeoutIntervalForResource = .infinity
                    let session = session ?? URLSession(configuration: configuration)
                    var request = URLRequest(url: url)
                    request.setValue(userID, forHTTPHeaderField: "X-Clack-User")
                    request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
                    request.timeoutInterval = 120
                    let (bytes, response) = try await session.bytes(for: request)
                    guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                        throw URLError(.badServerResponse)
                    }
                    var parser = SSEParser()
                    // Split on newlines ourselves: `bytes.lines` skips the empty lines that end an event.
                    var line: [UInt8] = []
                    for try await byte in bytes {
                        if byte == 0x0A {
                            if let event = parser.feed(String(decoding: line, as: UTF8.self)) { continuation.yield(event) }
                            line.removeAll(keepingCapacity: true)
                        } else {
                            line.append(byte)
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
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
/// with the first listener, closes after the last, and reconnects 5 s after a drop. The server sends the full live
/// state every tick, so nothing needs replaying.
@MainActor
public final class LiveHub {
    private var listeners: [UUID: AsyncStream<LiveUpdate>.Continuation] = [:]
    private var task: Task<Void, Never>?
    private let open: @Sendable () -> AsyncThrowingStream<SSEEvent, Error>
    private let retryDelay: Duration

    public init(retryDelay: Duration = .seconds(5), open: @escaping @Sendable () -> AsyncThrowingStream<SSEEvent, Error>) {
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
            while !Task.isCancelled {
                guard let self else { return }
                do {
                    for try await event in self.open() where event.name == "live" {
                        if let update = await EventStream.decode(LiveUpdate.self, from: event) {
                            self.deliver(update)
                        }
                    }
                } catch {
                    // Fall through to the retry.
                }
                if Task.isCancelled { return }
                try? await Task.sleep(for: self.retryDelay)
            }
        }
    }

    private func deliver(_ update: LiveUpdate) {
        for continuation in listeners.values { continuation.yield(update) }
    }
}
