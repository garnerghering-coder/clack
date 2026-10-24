//
//  BackgroundRefresh.swift
//  Clack
//

import BackgroundTasks
import ClackCore
import Foundation
import UIKit

/// Freshness with the app closed (docs/swift-port/API.md 2.13 "Freshness pushes"). Two ways in, one routine:
/// - a silent push from the server when a tracked leg's delay band, platform, cancellation or card phase changes
///   (`{"aps":{"content-available":1},"clack":{"legId","reason"}}`), handed over by the app delegate;
/// - a background refresh (`BGAppRefreshTask`), the fallback when pushes don't come, asked for 45 minutes before the next
///   departure and each morning (`RefreshSchedule`).
/// The routine is the foreground one (`ArrivalWatcher.refresh`): the legs, the details of the trips about to run, the
/// trip cards, the widgets' snapshot written at once and their timelines reloaded, and this phone's push addresses. It
/// gives up after 25 seconds, inside the 30 iOS allows.
@MainActor
final class BackgroundRefresh {
    static let shared = BackgroundRefresh()

    static let budget: Duration = .seconds(25)

    private var app: AppModel?
    /// The time last asked for (ms), so the same request isn't sent again.
    private var scheduled: Double?

    /// The app's model, set at launch (also a launch in the background).
    func attach(_ app: AppModel) { self.app = app }

    /// Tells iOS which code runs the refresh. Must happen before the app finishes launching.
    nonisolated static func register() {
        let ok = BGTaskScheduler.shared.register(forTaskWithIdentifier: RefreshSchedule.identifier, using: nil) { task in
            guard let task = task as? BGAppRefreshTask else {
                task.setTaskCompleted(success: false)
                return
            }
            Task { @MainActor in await BackgroundRefresh.shared.handle(task) }
        }
        if !ok { NSLog("Clack: the background refresh is not registered (missing from Info.plist?)") }
    }

    private func handle(_ task: BGAppRefreshTask) async {
        let work = Task { @MainActor in await run(changed: nil) }
        task.expirationHandler = { work.cancel() }
        let fresh = await work.value
        task.setTaskCompleted(success: fresh)
    }

    /// The server's silent push: which leg changed. (Its `reason`, `delay` to `finished`, needs nothing different: the
    /// routine fetches everything, and the Passport widgets reload after an arrival anyway.)
    struct Push: Sendable {
        var legId: String?

        /// Nil for a push that isn't Clack's.
        init?(_ userInfo: [AnyHashable: Any]) {
            guard let clack = userInfo["clack"] as? [String: Any] else { return nil }
            legId = clack["legId"] as? String
        }
    }

    /// A silent push: the leg it names has its details fetched again even if they were just kept.
    func handle(_ push: Push) async -> UIBackgroundFetchResult {
        await run(changed: push.legId) ? .newData : .failed
    }

    /// The routine, cut off after `budget`. True when the legs were fetched.
    @discardableResult
    func run(changed legId: String?) async -> Bool {
        guard let app else { return false }
        let work = Task { @MainActor in await refresh(app, changed: legId) }
        let timer = Task {
            try? await Task.sleep(for: Self.budget)
            work.cancel()
        }
        defer { timer.cancel() }
        let fresh = await work.value
        NSLog("Clack: background refresh for %@: %@", legId ?? "the schedule", fresh ? "fetched" : "not fetched")
        return fresh
    }

    private func refresh(_ app: AppModel, changed legId: String?) async -> Bool {
        // A launch in the background has no screen to load the settings: the language, the alerts switch and the
        // Passport options come from them.
        if app.state != .ready { await app.load() }
        let fresh = await app.arrivals.refresh(app, changed: legId, widgetsNow: true)
        await app.notifications.sync(app.client, enabled: app.settings.notify)
        return fresh
    }

    /// Asks iOS for the next refresh (it replaces the one asked for before). The simulator can't run them.
    func schedule(legs: [Leg]) {
        let at = RefreshSchedule.next(legs, now: Date.now.timeIntervalSince1970 * 1000, timeZone: .current)
        // The foreground refreshes every minute or two; ask again only when the time moved.
        guard at != scheduled else { return }
        let request = BGAppRefreshTaskRequest(identifier: RefreshSchedule.identifier)
        request.earliestBeginDate = Date(timeIntervalSince1970: at / 1000)
        do {
            try BGTaskScheduler.shared.submit(request)
            scheduled = at
        } catch {
            #if !targetEnvironment(simulator)
            NSLog("Clack: could not ask for a background refresh: %@", error.localizedDescription)
            #endif
        }
    }
}
