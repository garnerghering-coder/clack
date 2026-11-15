//
//  FollowedJourneys.swift
//  Clack
//

import ClackCore
import Foundation

/// The journeys other people shared that this phone follows (a card on Trips, a screen of their own, alerts from the
/// server). Following one also follows each of its trains, so Explore marks them on the map. It never touches your own
/// trips or your Passport.
@MainActor
@Observable
final class FollowedJourneys {
    private(set) var journeys: [SharedJourney] = []
    private(set) var loaded = false

    /// Fetches the ones that still work. A failed fetch keeps what is shown, and says why (nil: it answered).
    @discardableResult
    func load(_ app: AppModel) async -> APIError.Kind? {
        do {
            journeys = try await app.client.followedJourneys()
            loaded = true
            return nil
        } catch {
            return APIError.classify(error)
        }
    }

    func journey(_ token: String) -> SharedJourney? { journeys.first { $0.token == token } }

    /// Follows a shared journey: the link, then each of its trains. Nil when the link no longer works.
    func follow(token: String, app: AppModel) async -> SharedJourney? {
        guard let journey = try? await app.client.sharedJourney(token: token) else { return nil }
        do { try await app.client.followJourney(token: token) } catch { return nil }
        for body in SharedLogic.followBodies(journey) { try? await app.client.follow(body) }
        Usage.shared.count(.feature, "share.follow")
        await load(app)
        return journeys.first { $0.token == token } ?? journey
    }

    /// Stops following: the link and the trains it added.
    func stop(token: String, app: AppModel) async {
        let journey = self.journey(token)
        journeys.removeAll { $0.token == token }
        try? await app.client.unfollowJourney(token: token)
        for body in journey.map(SharedLogic.followBodies) ?? [] {
            try? await app.client.unfollow(number: body.trainNumber, date: body.serviceDate)
        }
    }

    enum Refresh {
        case fresh(SharedJourney)
        /// The link no longer works (stopped, or too long ago).
        case gone
        /// No answer (offline, a server hiccup): keep what is shown.
        /// Not reached, and why.
        case failed(APIError.Kind)
    }

    /// A fresher copy of one followed journey (or the first copy of one just opened).
    func refresh(token: String, app: AppModel) async -> Refresh {
        do {
            let fresh = try await app.client.sharedJourney(token: token)
            if let at = journeys.firstIndex(where: { $0.token == token }) { journeys[at] = fresh }
            return .fresh(fresh)
        } catch let error as APIError where error.status == 404 {
            return .gone
        } catch {
            return .failed(APIError.classify(error))
        }
    }
}
