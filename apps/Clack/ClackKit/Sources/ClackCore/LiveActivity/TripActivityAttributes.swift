//
//  TripActivityAttributes.swift
//  Clack
//

#if canImport(ActivityKit) && os(iOS)
import ActivityKit
import Foundation

/// The trip on the lock screen and in the Dynamic Island: the app starts and ends the activity, the widget extension
/// draws it, both from this one definition. The server sends the same shape to start and update it
/// (apps/server/src/push/notifier.ts), as plain JSON numbers: times are milliseconds since 1970.
public struct TripActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        /// scheduled | boarding | en_route | at_stop | arrived | cancelled
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
        /// approaching, boarding, enRoute, getOffSoon, changing, arrived or cancelled. Nil from an older server: the widget works it
        /// out from `status`.
        public var phase: String? = nil
        /// `platformChanged` for ten minutes after a platform change.
        public var note: String? = nil
        /// While changing trains: the next train's platform, and when it leaves (ms since 1970).
        public var changePlatform: String? = nil
        public var changeAt: Double? = nil

        public init(
            status: String, delayMin: Int? = nil, nextStop: String? = nil, nextStopAt: Double? = nil, platform: String? = nil,
            platformFor: String, progress: Double? = nil, departAt: Double? = nil, arriveAt: Double? = nil, canceled: Bool,
            phase: String? = nil, note: String? = nil, changePlatform: String? = nil, changeAt: Double? = nil
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
        }
    }

    public var legId: String
    public var journeyId: String?
    public var train: String?
    public var from: String
    public var to: String
    public var fromTz: String
    public var toTz: String
    /// The operator's colour, `#rrggbb`.
    public var color: String?

    public init(
        legId: String, journeyId: String? = nil, train: String? = nil, from: String, to: String, fromTz: String, toTz: String,
        color: String? = nil
    ) {
        self.legId = legId
        self.journeyId = journeyId
        self.train = train
        self.from = from
        self.to = to
        self.fromTz = fromTz
        self.toTz = toTz
        self.color = color
    }
}
#endif
