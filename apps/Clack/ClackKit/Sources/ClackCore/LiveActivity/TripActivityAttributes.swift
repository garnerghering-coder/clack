//
//  TripActivityAttributes.swift
//  Clack
//

#if canImport(ActivityKit) && os(iOS)
import ActivityKit
import Foundation

/// The trip on the lock screen and in the Dynamic Island: the app starts and ends the activity, the widget extension
/// draws it, both from this one definition. The server sends the same shape to start and update it
/// (apps/server/src/push/notifier.ts), as plain JSON numbers: times are milliseconds since 1970. The attributes are the
/// leg the card started on; the content state names the leg it shows now (`TripCardState.legId` and the fields after it).
public struct TripActivityAttributes: ActivityAttributes {
    public typealias ContentState = TripCardState

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

    /// The card as the start, end and de-dup rules see it (`TripCard`).
    public func card(_ state: ContentState) -> TripCard.Running {
        TripCard.Running(legId: state.legId ?? legId, journeyId: journeyId, startLegId: legId)
    }
}
#endif
