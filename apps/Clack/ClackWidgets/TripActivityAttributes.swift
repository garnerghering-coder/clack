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
    /// The train's drawing (an image in the widget's asset catalog), for the picture on the card. Optional.
    var art: String? = nil
    /// The route as `[lat, lon]` pairs, a few dozen points, for the sketch of the line on the card. Optional.
    var route: [[Double]]? = nil
}
