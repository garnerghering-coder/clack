//
//  TripCardState.swift
//  Clack
//

import Foundation

/// What the trip card (Live Activity) shows now: `TripActivityAttributes.ContentState`. It lives outside the ActivityKit
/// file so the rules that build it can be tested on the Mac. The server sends the same shape in `content-state`
/// (apps/server/src/push/notifier.ts `state`, docs/swift-port/API.md 2.13), as plain JSON numbers: times are milliseconds
/// since 1970. Keys the app doesn't declare are ignored, and every field added later is optional, so an older server or an
/// older app still decodes it.
public nonisolated struct TripCardState: Codable, Hashable, Sendable {
    /// scheduled | approaching | boarding | en_route | at_stop | arrived | cancelled
    public var status: String
    public var delayMin: Int?
    public var nextStop: String?
    public var nextStopAt: Double?
    public var platform: String?
    /// departure | arrival: which end the platform is for.
    public var platformFor: String
    /// 0 to 1 along the route.
    public var progress: Double?
    public var departAt: Double?
    public var arriveAt: Double?
    public var canceled: Bool
    /// The moment the trip is in, decided by the server (apps/server/src/push/rules.ts momentOf): scheduled, leaveSoon,
    /// approaching, boarding, enRoute, getOffSoon, changing, arrived or cancelled. Nil from an older server: the card works
    /// it out from `status`.
    public var phase: String? = nil
    /// `platformChanged` for ten minutes after a platform change.
    public var note: String? = nil
    /// While changing trains: the next train's platform, and when it leaves (ms since 1970).
    public var changePlatform: String? = nil
    public var changeAt: Double? = nil
    /// The leg the card shows now. One card follows a whole journey, so after a change these differ from the card's
    /// fixed attributes (which name the leg it started on). Nil from an older server: use the attributes.
    public var legId: String? = nil
    public var train: String? = nil
    public var from: String? = nil
    public var to: String? = nil
    public var fromTz: String? = nil
    public var toTz: String? = nil
    /// Where you sit on this leg ("4", "23"), when the trip has it.
    public var coach: String? = nil
    public var seat: String? = nil

    public init(
        status: String, delayMin: Int? = nil, nextStop: String? = nil, nextStopAt: Double? = nil, platform: String? = nil,
        platformFor: String, progress: Double? = nil, departAt: Double? = nil, arriveAt: Double? = nil, canceled: Bool,
        phase: String? = nil, note: String? = nil, changePlatform: String? = nil, changeAt: Double? = nil,
        legId: String? = nil, train: String? = nil, from: String? = nil, to: String? = nil, fromTz: String? = nil,
        toTz: String? = nil, coach: String? = nil, seat: String? = nil
    ) {
        self.status = status
        self.delayMin = delayMin
        self.nextStop = nextStop
        self.nextStopAt = nextStopAt
        self.platform = platform
        self.platformFor = platformFor
        self.progress = progress
        self.departAt = departAt
        self.arriveAt = arriveAt
        self.canceled = canceled
        self.phase = phase
        self.note = note
        self.changePlatform = changePlatform
        self.changeAt = changeAt
        self.legId = legId
        self.train = train
        self.from = from
        self.to = to
        self.fromTz = fromTz
        self.toTz = toTz
        self.coach = coach
        self.seat = seat
    }

    /// The moment: the server's word for it, or (from an older server) worked out from the status.
    public var moment: String {
        if let phase { return phase }
        if canceled || status == "cancelled" { return "cancelled" }
        switch status {
        case "arrived": return "arrived"
        case "boarding": return "boarding"
        case "approaching": return "approaching"
        case "en_route", "at_stop": return "enRoute"
        default: return "scheduled"
        }
    }
}
