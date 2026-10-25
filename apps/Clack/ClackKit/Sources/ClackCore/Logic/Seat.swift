//
//  Seat.swift
//  Clack
//

import Foundation

/// Where you sit on a train: the coach ("vagn") and seat ("plats") as the ticket prints them or as you typed them. The
/// server keeps each as trimmed text of at most 8 characters (docs/swift-port/API.md `PATCH /api/legs/:id`).
public nonisolated enum Seat {
    public static let maxLength = 8

    /// Trimmed, at most `maxLength` characters; nil when blank.
    public static func clean(_ text: String?) -> String? {
        guard let trimmed = text?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else { return nil }
        return String(trimmed.prefix(maxLength))
    }

    /// What changes when the coach and seat fields are saved: only the ones that differ from what the trip has, and
    /// nil when neither does (nothing to send).
    public static func patch(coach: String?, seat: String?, was leg: Leg) -> LegPatch? {
        let newCoach = clean(coach), newSeat = clean(seat)
        var patch = LegPatch()
        if newCoach != leg.coach { patch.coach = .some(newCoach) }
        if newSeat != leg.seat { patch.seat = .some(newSeat) }
        return patch.isEmpty ? nil : patch
    }

    /// "Car 4 · Seat 23" ("Vagn 4 · Plats 23"), or the half that is known; nil when neither is.
    @MainActor
    public static func label(_ l10n: L10n, coach: String?, seat: String?) -> String? {
        let parts = [clean(coach).map { l10n.t("seat.coach", ["coach": $0]) }, clean(seat).map { l10n.t("seat.seat", ["seat": $0]) }]
        let text = Format.join(parts)
        return text.isEmpty ? nil : text
    }
}

/// A change to a saved trip (`PATCH /api/legs/:id`). A field left nil is not sent (unchanged); `.some(nil)` is sent as
/// null, which clears it (a train type goes back to the typical one).
public nonisolated struct LegPatch: Encodable, Equatable, Sendable {
    public var trainType: String??
    public var coach: String??
    public var seat: String??
    /// The platform where you got on / off, typed where no source has one (the server refuses it otherwise).
    public var depPlatform: String??
    public var arrPlatform: String??

    public init(trainType: String?? = nil, coach: String?? = nil, seat: String?? = nil, depPlatform: String?? = nil, arrPlatform: String?? = nil) {
        self.trainType = trainType
        self.coach = coach
        self.seat = seat
        self.depPlatform = depPlatform
        self.arrPlatform = arrPlatform
    }

    /// The server refuses an empty patch ("nothing to change").
    public var isEmpty: Bool { trainType == nil && coach == nil && seat == nil && depPlatform == nil && arrPlatform == nil }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        // `encode` of an Optional writes null for nil: the key is there, so the server clears that field.
        if let trainType { try c.encode(trainType, forKey: .trainType) }
        if let coach { try c.encode(coach, forKey: .coach) }
        if let seat { try c.encode(seat, forKey: .seat) }
        if let depPlatform { try c.encode(depPlatform, forKey: .depPlatform) }
        if let arrPlatform { try c.encode(arrPlatform, forKey: .arrPlatform) }
    }

    private enum CodingKeys: String, CodingKey { case trainType, coach, seat, depPlatform, arrPlatform }
}
