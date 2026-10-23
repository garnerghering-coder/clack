//
//  TripActivityAttributes.swift
//  Clack
//

import ActivityKit
import Foundation

/// The trip on the lock screen and in the Dynamic Island. This file exists twice, identical: here (the app starts and
/// ends the activity) and in ClackWidgets (it draws it). The server sends the same shape to start and update it
/// (apps/server/src/push/notifier.ts), as plain JSON numbers: times are milliseconds since 1970.
struct TripActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        /// scheduled | boarding | en_route | at_stop | arrived | cancelled
        var status: String
        var delayMin: Int?
        var nextStop: String?
        var nextStopAt: Double?
        var platform: String?
        /// departure | arrival: which end the platform is for.
        var platformFor: String
        /// 0 to 1 along the route.
        var progress: Double?
        var departAt: Double?
        var arriveAt: Double?
        var canceled: Bool
        /// The moment the trip is in, decided by the server (apps/server/src/push/rules.ts momentOf): scheduled, leaveSoon,
        /// approaching, boarding, enRoute, getOffSoon, changing, arrived or cancelled. Nil from an older server: the widget works it
        /// out from `status`.
        var phase: String? = nil
        /// `platformChanged` for ten minutes after a platform change.
        var note: String? = nil
        /// While changing trains: the next train's platform, and when it leaves (ms since 1970).
        var changePlatform: String? = nil
        var changeAt: Double? = nil
    }

    var legId: String
    var journeyId: String?
    var train: String?
    var from: String
    var to: String
    var fromTz: String
    var toTz: String
    /// The operator's colour, `#rrggbb`.
    var color: String?
}
