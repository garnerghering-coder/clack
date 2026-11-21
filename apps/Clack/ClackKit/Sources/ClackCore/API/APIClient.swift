//
//  APIClient.swift
//  Clack
//

import Foundation

/// A non-2xx answer from the server: `{ error, duplicateOf? }` (docs/swift-port/API.md §1).
public nonisolated struct APIError: Error, Sendable, LocalizedError {
    public let status: Int
    /// The server's `error` text (English, not localised).
    public let message: String
    /// A leg id, on a 409 from `POST /legs`.
    public let duplicateOf: String?
    /// How long the server asked to be left alone (a 429's Retry-After header, or "try again in N seconds" in its text).
    public let retryAfter: TimeInterval?

    public var errorDescription: String? { message }

    public init(status: Int, message: String, duplicateOf: String?, retryAfter: TimeInterval? = nil) {
        self.status = status
        self.message = message
        self.duplicateOf = duplicateOf
        self.retryAfter = retryAfter
    }

    /// What kind of failure, as the person is told it and as retrying treats it.
    public enum Kind: Sendable, Equatable {
        /// The phone has no connection (or lost it on the way).
        case offline
        /// Asked, and no answer in time.
        case timeout
        /// The server can't be reached or says it's down for now (502, 503, 504).
        case serverDown
        /// The server answered with a fault of its own (500, or an answer that didn't read).
        case serverError
        /// Too many requests; the server's wait when it named one.
        case rateLimited(retryAfter: TimeInterval?)
        case notFound
        /// Refused (any other 4xx), with the server's reason.
        case rejected(String)
        /// The screen stopped asking (it closed, or the search changed).
        case cancelled

        /// Asking again can help: no connection, a timeout, the server down, too many requests. A refusal never.
        public var isRetryable: Bool {
            switch self {
            case .offline, .timeout, .serverDown, .rateLimited: true
            case .serverError, .notFound, .rejected, .cancelled: false
            }
        }

        /// The wait the server named, if it did.
        public var retryAfter: TimeInterval? {
            if case .rateLimited(let after) = self { return after }
            return nil
        }
    }

    /// The catalog key of what to do after a failure, said after the screen's own subject ("Couldn't save."): check
    /// the connection only when the phone is offline; the server not answering (down, too slow, too busy) or at fault
    /// says so (build 86 check: "Check your connection" while the phone was online and the server down); a refusal or
    /// an unknown cause just "Try again."
    public static func adviceKey(_ kind: Kind?) -> String {
        switch kind {
        case .offline: "failure.checkConnection"
        case .timeout, .serverDown, .rateLimited: "failure.serverNotAnswering"
        case .serverError: "failure.serverFault"
        case nil, .notFound, .rejected, .cancelled: "failure.tryAgain"
        }
    }

    public var kind: Kind {
        switch status {
        case 404: .notFound
        case 429: .rateLimited(retryAfter: retryAfter)
        case 502, 503, 504: .serverDown
        case 500..<600: .serverError
        default: .rejected(message)
        }
    }

    /// Any error a request can throw, as a kind: the server's answers by their status, URLSession's by their code.
    public static func classify(_ error: any Error) -> Kind {
        if let error = error as? APIError { return error.kind }
        if error is CancellationError { return .cancelled }
        if let error = error as? URLError {
            switch error.code {
            case .cancelled: return .cancelled
            case .timedOut: return .timeout
            case .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed, .internationalRoamingOff, .callIsActive,
                 .cannotFindHost, .dnsLookupFailed:
                return .offline
            case .cannotConnectToHost, .badServerResponse, .zeroByteResource, .cannotParseResponse, .secureConnectionFailed:
                return .serverDown
            default: return .offline
            }
        }
        // An answer that didn't decode is the server's fault; asking again gets the same answer.
        return .serverError
    }

    /// A Retry-After header (seconds, or an HTTP date), else the seconds in the server's text ("too many requests, try
    /// again in 12 seconds", apps/server/src/plugins/rateLimit.ts).
    public static func retryAfter(header: String?, message: String?, now: Date = .now) -> TimeInterval? {
        if let header = header?.trimmingCharacters(in: .whitespaces), !header.isEmpty {
            if let seconds = Double(header), seconds >= 0 { return seconds }
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = TimeZone(identifier: "GMT")
            formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
            if let date = formatter.date(from: header) { return max(0, date.timeIntervalSince(now)) }
        }
        if let message, let range = message.range(of: #"try again in (\d+) second"#, options: .regularExpression) {
            let digits = message[range].filter(\.isNumber)
            return Double(digits)
        }
        return nil
    }
}

/// What a request told about reaching the server: it answered, or it couldn't be reached (and how it failed). A 502 or
/// 504 is the proxy in front saying the server itself didn't answer.
public nonisolated enum Reach: Sendable, Equatable {
    case answered
    case failed(APIError.Kind)

    public var reached: Bool { self == .answered }
}

private nonisolated struct APIErrorBody: Decodable {
    public let error: String?
    public let message: String?
    public let duplicateOf: String?
}

/// Talks to the Clack server. One client per phone id.
public nonisolated struct APIClient: Sendable {
    public let base: URL
    public let userID: String
    /// The session the requests go on: the one given (tests), else `Connections.shared`'s, which is new after a while
    /// away from the screen.
    public var session: URLSession { fixedSession ?? Connections.shared.requests }
    private let fixedSession: URLSession?
    /// Kept copies of the GETs the web keeps, served when the server can't be reached. Nil in tests.
    public let cache: OfflineCache?
    /// Told after every request whether the server answered or couldn't be reached (and how).
    public let reachability: (@Sendable (Reach) -> Void)?

    /// GETs time out after 15 s (the web client does the same).
    public static let getTimeout: TimeInterval = 15

    public init(
        base: URL = Config.apiBase, userID: String, session: URLSession? = nil, cache: OfflineCache? = nil,
        reachability: (@Sendable (Reach) -> Void)? = nil
    ) {
        self.base = base
        self.userID = userID
        self.fixedSession = session
        self.cache = cache
        self.reachability = reachability
    }

    /// A URL under `/api`. Every segment is percent-encoded, including `:` (trip keys) and `|` (live-map ids).
    public func url(_ segments: [String], query: [String: String] = [:]) -> URL {
        // Built from text, not `appending(path:)`, which would encode the `%` of an already-encoded segment again.
        var text = base.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        text += "/" + (["api"] + segments.map(Self.encode)).joined(separator: "/")
        if !query.isEmpty {
            let items = query.sorted { $0.key < $1.key }.map { "\(Self.encode($0.key))=\(Self.encode($0.value))" }
            text += "?" + items.joined(separator: "&")
        }
        return URL(string: text) ?? base
    }

    private static func encode(_ segment: String) -> String {
        segment.addingPercentEncoding(withAllowedCharacters: .alphanumerics.union(CharacterSet(charactersIn: "-._~"))) ?? segment
    }

    /// Sends a request and returns the body (empty for 204). `Content-Type` is set only when there is a body:
    /// Fastify rejects an empty body labelled JSON.
    ///
    /// A failure that can pass (no connection, a timeout, the server down, too many requests) is asked again under
    /// `policy`: by default a GET up to five times with backoff, a write never by itself. A POST carries an
    /// `Idempotency-Key`, the same on every try, so asking again can't add the same thing twice. `retryIf` can turn a
    /// retry down (a GET with a kept copy serves that instead of waiting).
    public func request(
        _ method: String, _ segments: [String], query: [String: String] = [:], body: (any Encodable & Sendable)? = nil,
        timeout: TimeInterval? = nil, policy: RetryPolicy? = nil, retryIf: ((any Error) async -> Bool)? = nil
    ) async throws -> Data {
        var request = URLRequest(url: url(segments, query: query))
        request.httpMethod = method
        request.setValue(userID, forHTTPHeaderField: "X-Clack-User")
        if method == "GET" { request.timeoutInterval = timeout ?? Self.getTimeout }
        if method == "POST" { request.setValue(UUID().uuidString, forHTTPHeaderField: "Idempotency-Key") }
        if let body {
            request.httpBody = try JSONEncoder().encode(body)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        let policy = policy ?? RetryContext.policy ?? (method == "GET" ? .read : .none)
        let observer = RetryContext.observer
        var retrier = Retrier(policy)
        while true {
            let epoch = AppPresence.shared.epoch
            do {
                let data = try await attempt(request, epoch: epoch)
                if retrier.status != .idle { observer?(.idle) }
                return data
            } catch {
                let kind = APIError.classify(error)
                // A read frozen on the way (the app left the screen with it open): asked again at once, not counted as
                // a failure. The epoch moves only when the app leaves, so this can't loop. A write is left to its
                // caller, as always.
                if method == "GET", kind != .cancelled, kind.isRetryable, AppPresence.shared.epoch != epoch {
                    try Task.checkCancellation()
                    continue
                }
                let wanted = kind.isRetryable ? await retryIf?(error) ?? true : false
                guard wanted, let delay = retrier.failed(kind), case .retrying = retrier.status else {
                    if kind != .cancelled, retrier.status != .idle || kind.isRetryable { observer?(.gaveUp(kind)) }
                    throw error
                }
                observer?(retrier.status)
                // Woken early when the connection comes back or the app comes to the front.
                try await RetryWake.shared.sleep(delay)
            }
        }
    }

    /// One try: the answer's body, or the failure (and the server's reachability said either way). A failure of a
    /// request that began before the app last left the screen says nothing: the freeze cut it, not the server.
    private func attempt(_ request: URLRequest, epoch: Int) async throws -> Data {
        let (data, response): (Data, URLResponse)
        let log = NetworkLog.shared.enabled ? UUID() : nil
        let started = Date()
        do {
            (data, response) = try await session.data(for: request, delegate: log.map { MetricsCatcher(id: $0) })
        } catch {
            // A network failure or the 15 s timeout means unreachable; a request the page cancelled doesn't.
            let kind = APIError.classify(error)
            let frozen = AppPresence.shared.epoch != epoch
            if kind != .cancelled, !frozen { reachability?(.failed(kind)) }
            if let log { NetworkLog.shared.note(Self.logLine(request, started, failure: error, frozen: frozen), id: log) }
            throw error
        }
        guard let http = response as? HTTPURLResponse else {
            reachability?(.failed(.serverDown))
            throw URLError(.badServerResponse)
        }
        if let log { NetworkLog.shared.note(Self.logLine(request, started, status: http.statusCode), id: log) }
        // The proxy in front answering for a server that didn't is not the server answering.
        reachability?(http.statusCode == 502 || http.statusCode == 504 ? .failed(.serverDown) : .answered)
        guard (200..<300).contains(http.statusCode) else {
            let parsed = try? JSONDecoder().decode(APIErrorBody.self, from: data)
            let message = parsed?.error ?? parsed?.message ?? "HTTP \(http.statusCode)"
            throw APIError(
                status: http.statusCode,
                message: message,
                duplicateOf: parsed?.duplicateOf,
                retryAfter: http.statusCode == 429 || http.statusCode == 503
                    ? APIError.retryAfter(header: http.value(forHTTPHeaderField: "Retry-After"), message: message) : nil
            )
        }
        return data
    }

    /// A request's line in the Network log: method, path, outcome and how long it took.
    static func logLine(_ request: URLRequest, _ started: Date, status: Int? = nil, failure: (any Error)? = nil, frozen: Bool = false) -> String {
        let path = request.url.map { $0.path + ($0.query.map { "?" + $0 } ?? "") } ?? "?"
        let ms = Int((Date().timeIntervalSince(started) * 1000).rounded())
        var outcome = status.map { String($0) } ?? "failed"
        if let failure {
            outcome = (failure as? URLError).map { "URLError \($0.code.rawValue)" } ?? String(describing: failure)
            outcome += " (\(APIError.classify(failure)))"
            if frozen { outcome += ", cut by the app leaving" }
        }
        return "\(request.httpMethod ?? "GET") \(path) → \(outcome) in \(ms) ms"
    }

    /// The path a copy is kept under: the path itself, and for the Passport its query too (sorted, so the same choices match).
    public nonisolated static func cacheKey(_ path: String, _ query: [String: String]) -> String {
        guard path == "/passport", !query.isEmpty else { return path }
        return path + "?" + query.sorted { $0.key < $1.key }.map { "\($0.key)=\($0.value)" }.joined(separator: "&")
    }

    /// Leaves these kept copies alone when old ones are dropped (the trips about to be ridden).
    public func pin(_ paths: Set<String>) async { await cache?.setPinned(paths) }

    /// A GET, decoded. When the server can't be reached, the kept copy of the same path is used if there is one, at
    /// once: the screen has something to show, and its own loop asks again later.
    public func get<T: Decodable & Sendable>(_ segments: [String], query: [String: String] = [:], timeout: TimeInterval? = nil) async throws -> T {
        let path = "/" + segments.joined(separator: "/")
        let key = Self.cacheKey(path, query)
        let cache = cache
        let data: Data
        do {
            data = try await request("GET", segments, query: query, timeout: timeout) { error in
                // Waiting out a backoff makes sense only when there is nothing kept to show meanwhile.
                guard Self.servesKept(error), let cache else { return true }
                return await cache.read(key) == nil
            }
        } catch let error where Self.servesKept(error) {
            // Any answer from the server itself, even an error, is not served from the cache; only a failure to reach it.
            guard let cache, let kept = await cache.read(key) else { throw error }
            return try JSONDecoder().decode(T.self, from: kept)
        }
        // Responses without a query are kept; so is the Passport, per year and setting (its query is part of the key).
        if query.isEmpty || path == "/passport" { await cache?.store(key, data) }
        return try JSONDecoder().decode(T.self, from: data)
    }

    /// The failures a kept copy stands in for: the server not reached (no connection, no answer in time, the proxy in
    /// front saying it isn't answering). A 503 is the server's own answer (a source it relies on is down), so it isn't.
    private static func servesKept(_ error: any Error) -> Bool {
        if let error = error as? APIError { return error.status == 502 || error.status == 504 }
        return error is URLError && APIError.classify(error) != .cancelled
    }

    /// A request with a JSON body whose answer is decoded (`POST /legs`, `PATCH /legs/:id`, ...).
    public func send<T: Decodable & Sendable>(
        _ method: String, _ segments: [String], query: [String: String] = [:], body: (any Encodable & Sendable)? = nil
    ) async throws -> T {
        let data = try await request(method, segments, query: query, body: body)
        return try JSONDecoder().decode(T.self, from: data)
    }

    /// Uploads a file as it is (`PUT /walklogs/:id`): the body is raw bytes, not JSON.
    public func upload(_ segments: [String], data: Data, contentType: String = "application/octet-stream") async throws {
        var request = URLRequest(url: url(segments))
        request.httpMethod = "PUT"
        request.setValue(userID, forHTTPHeaderField: "X-Clack-User")
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 120
        let (body, response) = try await session.upload(for: request, from: data)
        guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        guard (200..<300).contains(http.statusCode) else {
            let parsed = try? JSONDecoder().decode(APIErrorBody.self, from: body)
            let message = parsed?.error ?? parsed?.message ?? "HTTP \(http.statusCode)"
            throw APIError(
                status: http.statusCode, message: message, duplicateOf: nil,
                retryAfter: APIError.retryAfter(header: http.value(forHTTPHeaderField: "Retry-After"), message: message)
            )
        }
    }

    /// A request whose answer has no body of interest (a 204, or a flag we don't read).
    public func perform(_ method: String, _ segments: [String], query: [String: String] = [:], body: (any Encodable & Sendable)? = nil) async throws {
        _ = try await request(method, segments, query: query, body: body)
    }
}
