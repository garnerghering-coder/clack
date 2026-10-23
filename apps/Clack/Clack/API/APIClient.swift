//
//  APIClient.swift
//  Clack
//

import Foundation

/// A non-2xx answer from the server: `{ error, duplicateOf? }` (docs/swift-port/API.md §1).
nonisolated struct APIError: Error, Sendable, LocalizedError {
    let status: Int
    /// The server's `error` text (English, not localised).
    let message: String
    /// A leg id, on a 409 from `POST /legs`.
    let duplicateOf: String?

    var errorDescription: String? { message }
}

private nonisolated struct APIErrorBody: Decodable {
    let error: String?
    let message: String?
    let duplicateOf: String?
}

/// Talks to the Clack server. One client per phone id.
nonisolated struct APIClient: Sendable {
    let base: URL
    let userID: String
    let session: URLSession

    /// GETs time out after 15 s (the web client does the same).
    static let getTimeout: TimeInterval = 15

    init(base: URL = Config.apiBase, userID: String, session: URLSession = .shared) {
        self.base = base
        self.userID = userID
        self.session = session
    }

    /// A URL under `/api`. Every segment is percent-encoded, including `:` (trip keys) and `|` (live-map ids).
    func url(_ segments: [String], query: [String: String] = [:]) -> URL {
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
    func request(_ method: String, _ segments: [String], query: [String: String] = [:], body: (any Encodable & Sendable)? = nil) async throws -> Data {
        var request = URLRequest(url: url(segments, query: query))
        request.httpMethod = method
        request.setValue(userID, forHTTPHeaderField: "X-Clack-User")
        if method == "GET" { request.timeoutInterval = Self.getTimeout }
        if let body {
            request.httpBody = try JSONEncoder().encode(body)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        let (data, response) = try await session.data(for: request)
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

    func get<T: Decodable & Sendable>(_ segments: [String], query: [String: String] = [:]) async throws -> T {
        let data = try await request("GET", segments, query: query)
        return try JSONDecoder().decode(T.self, from: data)
    }
}
