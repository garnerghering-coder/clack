//
//  LiveActivities.swift
//  Clack
//

import ActivityKit
import ClackCore
import Foundation

/// The trip card on the lock screen and in the Dynamic Island (owner, 2026-10-23). The server updates it by push, so it
/// keeps moving with the app closed, and follows the whole journey: one card per journey, moved on to the next train at
/// a change, ended when the journey is over (docs/swift-port/API.md 2.13). Here the app:
/// - from launch (also a launch in the background, which is how iOS hands over a card the server started), watches every
///   card and gives the server each one's update address, with this phone's own address;
/// - starts a card for a journey that is about to leave (or running) while the app is open, if it has none yet;
/// - keeps a card that has no push address (no push entitlement) up to date itself while the app is open;
/// - ends cards whose journey is over. The rules are in ClackCore (`TripCard`), the same as the server's.
@MainActor
final class LiveActivityManager {
    static let shared = LiveActivityManager()

    private var client: (@MainActor () -> APIClient)?
    private var observing = Set<String>()
    /// Each card's push address, by activity id.
    private var pushTokens = [String: String]()
    /// What was last sent for each card, so it isn't sent again.
    private var reported = [String: String]()

    /// Journeys that have had a card on this phone, so a card swiped away doesn't come back (as on the server).
    private static let startedKey = "clack.tripCardJourneys"
    private var started: Set<String> { Set(UserDefaults.standard.stringArray(forKey: Self.startedKey) ?? []) }
    private func remember(_ key: String) {
        var all = UserDefaults.standard.stringArray(forKey: Self.startedKey) ?? []
        guard !all.contains(key) else { return }
        all.append(key)
        UserDefaults.standard.set(Array(all.suffix(100)), forKey: Self.startedKey)
    }

    /// Debug sample cards (Settings > Test alerts) are left alone by the rules.
    static func isSample(_ activity: Activity<TripActivityAttributes>) -> Bool { activity.attributes.legId.hasPrefix("debug-") }

    private static func nowMs() -> Double { Date.now.timeIntervalSince1970 * 1000 }

    /// Called once at launch: watches each card that exists or appears, and the push-to-start address (iOS 17.2+).
    func observe(client: @escaping @MainActor () -> APIClient) {
        guard self.client == nil else { return }
        self.client = client
        for activity in Activity<TripActivityAttributes>.activities { watch(activity) }
        Task {
            for await activity in Activity<TripActivityAttributes>.activityUpdates { watch(activity) }
        }
        if #available(iOS 17.2, *) {
            Task {
                for await data in Activity<TripActivityAttributes>.pushToStartTokenUpdates {
                    NotificationManager.shared.setStartToken(data)
                }
            }
        }
    }

    /// The app came to the front: catch up, and send again any card whose details changed (the phone's own address
    /// arrived, or the identity changed).
    func resume() {
        for activity in Activity<TripActivityAttributes>.activities {
            watch(activity)
            Task { await report(activity) }
        }
    }

    private func watch(_ activity: Activity<TripActivityAttributes>) {
        guard observing.insert(activity.id).inserted else { return }
        let sample = Self.isSample(activity)
        if !sample { remember(activity.attributes.card(activity.content.state).journeyKey) }
        if let token = activity.pushToken { pushTokens[activity.id] = hexToken(token) }
        Task {
            for await data in activity.pushTokenUpdates {
                pushTokens[activity.id] = hexToken(data)
                await report(activity)
            }
        }
        Task {
            for await state in activity.activityStateUpdates where state == .ended || state == .dismissed {
                if let token = pushTokens[activity.id], !sample, let client = client?() { try? await client.forgetActivity(token) }
                pushTokens[activity.id] = nil
                reported[activity.id] = nil
                observing.remove(activity.id)
                break
            }
        }
    }

    /// Tells the server where this card is reached: the leg it shows now (the server may have moved it on), and the phone.
    private func report(_ activity: Activity<TripActivityAttributes>) async {
        guard !Self.isSample(activity), let token = pushTokens[activity.id], let client = client?(),
              activity.activityState == .active || activity.activityState == .stale else { return }
        let legId = activity.content.state.legId ?? activity.attributes.legId
        let device = NotificationManager.shared.deviceToken
        let key = [token, legId, device ?? "", client.userID].joined(separator: "|")
        guard reported[activity.id] != key else { return }
        do {
            try await client.registerActivity(ActivityRegistration(
                token: token, legId: legId, environment: NotificationManager.environment, deviceToken: device
            ))
            reported[activity.id] = key
        } catch {
            reported[activity.id] = nil
        }
    }

    private var current: [Activity<TripActivityAttributes>] {
        Activity<TripActivityAttributes>.activities.filter {
            !Self.isSample($0) && ($0.activityState == .active || $0.activityState == .stale)
        }
    }

    /// After each fetch of the trips: end the cards whose journey is over, bring the app's own cards up to date, and
    /// start one for a journey about to leave (or running) that has none.
    func refresh(legs: [Leg], enabled: Bool, settings: Settings) async {
        SharedSettings.write(language: settings.language, clock: settings.clock)
        let now = Self.nowMs()
        for activity in current {
            let card = activity.attributes.card(activity.content.state)
            let leg = TripCard.currentLeg(card, legs: legs, now: now)
            let state = leg.flatMap { TripCard.state(for: $0, legs: legs, now: now) }
            if TripCard.isFinished(card, legs: legs) {
                await activity.end(state.map { ActivityContent(state: $0, staleDate: nil) }, dismissalPolicy: .after(.now + 600))
            } else if activity.pushToken == nil, let state, state != activity.content.state {
                // No push for this card: the app is the only one who can move it.
                await activity.update(ActivityContent(state: state, staleDate: Date(timeIntervalSinceNow: 300)))
            }
        }
        guard enabled, ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let running = current.map { $0.attributes.card($0.content.state) }
        for leg in TripCard.toStart(legs, running: running, started: started, now: now) { start(leg, legs: legs, now: now) }
    }

    /// Starts a card for a leg, with push when it can (the server then keeps it moving), else without (`push` false).
    @discardableResult
    func start(_ leg: Leg, legs: [Leg], now: Double) -> (activity: Activity<TripActivityAttributes>, push: Bool)? {
        guard let state = TripCard.state(for: leg, legs: legs, now: now), let origin = leg.origin, let destination = leg.destination
        else { return nil }
        let attributes = TripActivityAttributes(
            legId: leg.id, journeyId: leg.journeyId, train: leg.trainNumber, from: origin.name, to: destination.name,
            fromTz: origin.tz, toTz: destination.tz, color: leg.operator?.brandColor
        )
        // Stale after five minutes without news, as the server's pushes are.
        let content = ActivityContent(state: state, staleDate: Date(timeIntervalSinceNow: 300))
        let activity: Activity<TripActivityAttributes>
        var push = true
        do {
            activity = try Activity.request(attributes: attributes, content: content, pushType: .token)
        } catch {
            guard let local = try? Activity.request(attributes: attributes, content: content, pushType: nil) else {
                NSLog("Clack: could not start the trip card: %@", error.localizedDescription)
                return nil
            }
            activity = local
            push = false
        }
        remember(TripCard.journeyKey(leg))
        watch(activity)
        return (activity, push)
    }
}
