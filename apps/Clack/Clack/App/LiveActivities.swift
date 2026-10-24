//
//  LiveActivities.swift
//  Clack
//

import ActivityKit
import ClackCore
import Foundation

/// The trip card on the lock screen and in the Dynamic Island (owner, 2026-10-23). The server updates it by push, so it
/// keeps moving with the app closed. Here the app starts it when a trip is about to leave (or running) and the app is
/// open, gives the server each card's address, and ends cards for trips that are over. On iOS 17.2+ the server can also
/// start one itself, using the push-to-start address this passes on.
@MainActor
@Observable
final class LiveActivityManager {
    static let shared = LiveActivityManager()

    private var observing = Set<String>()
    private var reported = [String: String]()
    private var watchingStart = false

    /// Starts a card for the trip that leaves within 30 minutes or is running, if there isn't one yet.
    func start(for leg: Leg, enabled: Bool, client: APIClient) {
        guard enabled, ActivityAuthorizationInfo().areActivitiesEnabled,
              !leg.canceled, leg.actualArr == nil,
              let dep = TripsLogic.expected(leg).dep, let arr = TripsLogic.expected(leg).arr,
              let origin = leg.origin, let destination = leg.destination else { return }
        let now = Date.now.timeIntervalSince1970 * 1000
        guard dep - now <= 30 * 60_000, arr > now else { return }
        if Activity<TripActivityAttributes>.activities.contains(where: { $0.attributes.legId == leg.id }) { return }
        let attributes = TripActivityAttributes(
            legId: leg.id, journeyId: leg.journeyId, train: leg.trainNumber, from: origin.name, to: destination.name,
            fromTz: origin.tz, toTz: destination.tz, color: leg.operator?.brandColor
        )
        let state = TripActivityAttributes.ContentState(
            status: leg.live?.status.rawValue ?? "scheduled", delayMin: leg.arrDelayMin, nextStop: nil, nextStopAt: nil,
            platform: leg.depPlatform, platformFor: "departure", progress: leg.live?.progress, departAt: dep, arriveAt: arr, canceled: false
        )
        let content = ActivityContent(state: state, staleDate: Date(timeIntervalSince1970: arr / 1000 + 900))
        // With push (the server updates it with the app closed); without it (no push entitlement yet) the app updates it.
        if let activity = try? Activity.request(attributes: attributes, content: content, pushType: .token) {
            watch(activity, client: client)
        } else if (try? Activity.request(attributes: attributes, content: content, pushType: nil)) == nil {
            NSLog("Clack: could not start the trip card")
        }
    }

    /// Cards that exist already (the server may have started one while the app was closed): tell the server where each
    /// can be reached, and the push-to-start address.
    func resume(client: APIClient) {
        for activity in Activity<TripActivityAttributes>.activities { watch(activity, client: client) }
        guard #available(iOS 17.2, *), !watchingStart else { return }
        watchingStart = true
        Task {
            for await data in Activity<TripActivityAttributes>.pushToStartTokenUpdates {
                NotificationManager.shared.setStartToken(data)
            }
        }
    }

    private func watch(_ activity: Activity<TripActivityAttributes>, client: APIClient) {
        guard observing.insert(activity.id).inserted else { return }
        let legId = activity.attributes.legId
        Task {
            for await data in activity.pushTokenUpdates {
                let token = data.map { String(format: "%02x", $0) }.joined()
                if reported[activity.id] != token {
                    try? await client.registerActivity(token: token, legId: legId, environment: NotificationManager.environment)
                    reported[activity.id] = token
                }
            }
        }
        Task {
            for await state in activity.activityStateUpdates where state == .ended || state == .dismissed {
                if let token = reported[activity.id] { try? await client.forgetActivity(token) }
                reported[activity.id] = nil
                observing.remove(activity.id)
            }
        }
    }

    /// Ends the cards of trips that are over.
    func endFinished(legs: [Leg]) async {
        let done = Set(legs.filter { $0.actualArr != nil || $0.canceled }.map(\.id))
        for activity in Activity<TripActivityAttributes>.activities where done.contains(activity.attributes.legId) {
            await activity.end(nil, dismissalPolicy: .after(.now + 600))
        }
    }
}
