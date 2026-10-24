//
//  WidgetFeed.swift
//  Clack
//

import ClackCore
import Foundation
import WidgetKit

/// The fast path for the widgets: after the legs refresh, the app writes what it already has into the widgets' cache
/// (`WidgetSnapshot`) and asks WidgetKit to redraw the widgets whose part changed. The widgets also fetch for
/// themselves (`WidgetData.load`), so this only makes them quicker. Runs at most every 30 s; a call in between is held
/// until then and the latest legs are written. With no App Group nothing is written.
@MainActor
enum WidgetFeed {
    static let debounceMs: Double = 30_000
    /// The Passport, stats and year are fetched again after this long, or after a trip arrives.
    static let passportMaxAgeMs: Double = 30 * 60_000
    /// A favourite station's board is fetched again after this long.
    static let boardMaxAgeMs: Double = 10 * 60_000

    private static var lastRun: Double = 0
    private static var latest: (legs: [Leg], details: [String: LegDetail])?
    private static var trailing: Task<Void, Never>?

    private static func nowMs() -> Double { Date.now.timeIntervalSince1970 * 1000 }

    /// `immediate` (the background routine, which has seconds to finish) writes now, however recent the last write.
    static func refresh(legs: [Leg], details: [String: LegDetail], app: AppModel, immediate: Bool = false) async {
        guard WidgetSnapshot.containerURL != nil else { return }
        latest = (legs, details)
        let wait = lastRun + debounceMs - nowMs()
        if wait > 0, !immediate {
            // One write is already waiting: it will take these legs.
            guard trailing == nil else { return }
            trailing = Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(Int(wait)))
                trailing = nil
                await run(app)
            }
            return
        }
        await run(app)
    }

    private static func run(_ app: AppModel) async {
        guard let (legs, details) = latest else { return }
        latest = nil
        let now = nowMs()
        lastRun = now
        let before = WidgetSnapshot.load() ?? WidgetSnapshot()
        var s = before
        s.language = app.settings.language
        s.clock = app.settings.clock
        s.distanceUnit = app.settings.distanceUnit
        // Offline the legs are the kept copy: the widgets keep what they had rather than call it fresh.
        if !app.isOffline {
            (s.journey, s.nextJourney) = WidgetData.journeys(legs, details: details, now: now)
            s.updatedAt = now
        }

        let client = app.client
        let settings = app.settings
        // A trip that arrived since the Passport was fetched is in it now.
        let arrived = legs.contains { leg in
            let arr = TripsLogic.arrivalOf(leg)
            return !leg.canceled && arr <= now && arr > s.passportUpdatedAt
        }
        if !app.isOffline, arrived || now - s.passportUpdatedAt > passportMaxAgeMs,
           let all = try? await client.passport(year: nil, commuter: settings.includeCommuter, comparison: settings.co2Comparison) {
            let l10n = app.l10n
            let language = settings.language
            s.passport = WidgetData.passportBits(all, year: nil) { l10n.milestoneLabel($0, language: language) }
            s.stats = WidgetData.statsBits(all) { l10n.countryName($0) }
            let year = Calendar.current.component(.year, from: .now)
            if let yearly = try? await client.passport(year: year, commuter: settings.includeCommuter, comparison: settings.co2Comparison) {
                s.year = WidgetData.yearBits(yearly, year: year)
            }
            s.passportUpdatedAt = now
        }

        // The widgets never make a phone id: they use the app's (also for the station picker).
        Identity.shareWithWidgets(client.userID)
        let favourites = app.isOffline ? nil : try? await client.favoriteStations()
        if !app.isOffline { await keepStationLists(favourites: favourites, client: client, now: now) }
        if let favourites {
            for station in favourites.prefix(3) {
                let cached = s.boards.first { $0.id == station.id }
                if let cached, now - cached.updatedAt < boardMaxAgeMs { continue }
                guard var board = await WidgetData.board(station.id, cached: cached, client: client, now: now) else { continue }
                board.name = station.name
                s.boards.removeAll { $0.id == station.id }
                s.boards.append(board)
            }
        }

        guard s.save() else { return }
        let center = WidgetCenter.shared
        let languageChanged = s.language != before.language || s.clock != before.clock || s.distanceUnit != before.distanceUnit
        if languageChanged {
            center.reloadAllTimelines()
            return
        }
        if s.journey != before.journey || s.nextJourney != before.nextJourney { center.reloadTimelines(ofKind: WidgetKinds.nextJourney) }
        if s.passport != before.passport || s.stats != before.stats || s.year != before.year {
            for kind in [WidgetKinds.passport, WidgetKinds.stats, WidgetKinds.year] { center.reloadTimelines(ofKind: kind) }
        }
        if s.boards.map(\.rows) != before.boards.map(\.rows) { center.reloadTimelines(ofKind: WidgetKinds.departures) }
    }

    /// The Departures widget's picker lists (favourites, recent, big stations) as the app sees them, for when the
    /// extension can't reach the server itself.
    private static func keepStationLists(favourites: [StationHit]?, client: APIClient, now: Double) async {
        let kept = WidgetStations.load() ?? WidgetStations()
        let recent = try? await client.recentStations()
        let askPopular = kept.popular.isEmpty || now - kept.popularAt > WidgetData.popularMaxAgeMs
        let popular = askPopular ? try? await client.popularStations() : nil
        let updated = WidgetData.merged(kept, .init(favourites: favourites, recent: recent, popular: popular), now: now)
        if updated != kept { updated.save() }
    }
}
