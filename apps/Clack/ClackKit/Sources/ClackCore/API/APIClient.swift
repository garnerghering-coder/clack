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

    public var errorDescription: String? { message }

    public init(status: Int, message: String, duplicateOf: String?) {
        self.status = status
        self.message = message
        self.duplicateOf = duplicateOf
    }
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
    public let session: URLSession
    /// Kept copies of the GETs the web keeps, served when the server can't be reached. Nil in tests.
    public let cache: OfflineCache?
    /// Told after every request whether the server answered (true) or couldn't be reached (false).
    public let reachability: (@Sendable (Bool) -> Void)?

    /// GETs time out after 15 s (the web client does the same).
    public static let getTimeout: TimeInterval = 15

    public init(
        base: URL = Config.apiBase, userID: String, session: URLSession = .shared, cache: OfflineCache? = nil,
        reachability: (@Sendable (Bool) -> Void)? = nil
    ) {
        self.base = base
        self.userID = userID
        self.session = session
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
    public func request(_ method: String, _ segments: [String], query: [String: String] = [:], body: (any Encodable & Sendable)? = nil) async throws -> Data {
        var request = URLRequest(url: url(segments, query: query))
        request.httpMethod = method
        request.setValue(userID, forHTTPHeaderField: "X-Clack-User")
        if method == "GET" { request.timeoutInterval = Self.getTimeout }
        if let body {
            request.httpBody = try JSONEncoder().encode(body)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            // A network failure or the 15 s timeout means offline; a request the page cancelled doesn't.
            if (error as? URLError)?.code != .cancelled { reachability?(false) }
            throw error
        }
        reachability?(true)
        guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        guard (200..<300).contains(http.statusCode) else {
            let parsed = try? JSONDecoder().decode(APIErrorBody.self, from: data)
            throw APIError(
                status: http.statusCode,
                message: parsed?.error ?? parsed?.message ?? "HTTP \(http.statusCode)",
                duplicateOf: parsed?.duplicateOf
            )
        }
        return data
    }

    /// The path a copy is kept under: the path itself, and for the Passport its query too (sorted, so the same choices match).
    public nonisolated static func cacheKey(_ path: String, _ query: [String: String]) -> String {
        guard path == "/passport", !query.isEmpty else { return path }
        return path + "?" + query.sorted { $0.key < $1.key }.map { "\($0.key)=\($0.value)" }.joined(separator: "&")
    }

    /// Leaves these kept copies alone when old ones are dropped (the trips about to be ridden).
    public func pin(_ paths: Set<String>) async { await cache?.setPinned(paths) }

    /// A GET, decoded. When the server can't be reached, the kept copy of the same path is used if there is one.
    public func get<T: Decodable & Sendable>(_ segments: [String], query: [String: String] = [:]) async throws -> T {
        let path = "/" + segments.joined(separator: "/")
        let data: Data
        do {
            data = try await request("GET", segments, query: query)
        } catch let error as URLError where error.code != .cancelled {
            // Any HTTP answer, even an error, is not served from the cache; only a failure to reach the server is.
            guard let cache, let kept = await cache.read(Self.cacheKey(path, query)) else { throw error }
            return try JSONDecoder().decode(T.self, from: kept)
        }
        // Responses without a query are kept; so is the Passport, per year and setting (its query is part of the key).
        if query.isEmpty || path == "/passport" { await cache?.store(Self.cacheKey(path, query), data) }
        return try JSONDecoder().decode(T.self, from: data)
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
            throw APIError(status: http.statusCode, message: parsed?.error ?? parsed?.message ?? "HTTP \(http.statusCode)", duplicateOf: nil)
        }
    }

    /// A request whose answer has no body of interest (a 204, or a flag we don't read).
    public func perform(_ method: String, _ segments: [String], query: [String: String] = [:], body: (any Encodable & Sendable)? = nil) async throws {
        _ = try await request(method, segments, query: query, body: body)
    }
}
