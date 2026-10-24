//
//  PushBodies.swift
//  Clack
//

import Foundation

/// A push address the server keeps (docs/swift-port/API.md 2.13 `PUT /api/devices`): a missing key leaves the stored
/// value as it is, `null` clears it.
public nonisolated enum TokenUpdate: Equatable, Sendable {
    /// Leave the key out: the server keeps what it has (a launch that doesn't know the address yet).
    case keep
    /// Send `null`: the server forgets it.
    case clear
    case set(String)

    /// `.set` when known, `.keep` otherwise.
    public init(_ token: String?) {
        self = token.map(TokenUpdate.set) ?? .keep
    }
}

/// The body of `PUT /api/devices`.
public nonisolated struct DeviceRegistration: Encodable, Equatable, Sendable {
    public var token: String
    public var environment: String
    public var startToken: TokenUpdate

    public init(token: String, environment: String, startToken: TokenUpdate = .keep) {
        self.token = token
        self.environment = environment
        self.startToken = startToken
    }

    private enum CodingKeys: String, CodingKey { case token, environment, startToken }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(token, forKey: .token)
        try container.encode(environment, forKey: .environment)
        switch startToken {
        case .keep: break
        case .clear: try container.encodeNil(forKey: .startToken)
        case .set(let value): try container.encode(value, forKey: .startToken)
        }
    }
}

/// The body of `PUT /api/live-activities`: where the server sends one card's updates, and the phone it is on.
public nonisolated struct ActivityRegistration: Encodable, Equatable, Sendable {
    public var token: String
    public var legId: String
    public var environment: String
    /// The phone's own push address; left out when not known yet (the server keeps the stored one).
    public var deviceToken: String?

    public init(token: String, legId: String, environment: String, deviceToken: String? = nil) {
        self.token = token
        self.legId = legId
        self.environment = environment
        self.deviceToken = deviceToken
    }
}

/// Apple's push addresses as the server wants them: lower-case hex.
public nonisolated func hexToken(_ data: Data) -> String {
    data.map { String(format: "%02x", $0) }.joined()
}
