//
//  ArrivalWatcher.swift
//  Clack
//

import Foundation

/// A journey that has just ended and is due its celebration.
struct ArrivalMoment: Identifiable, Hashable {
    /// The journey's last leg.
    let legId: String
    /// The journey to load (`GET /api/journeys/:id`), or nil for a single leg.
    let journeyId: String?
    var id: String { legId }
}

/// Watches your trips for the end of a journey, whichever tab you are on (owner, 2026-10-23). A journey is watched
/// once its last leg is seen still ahead; a trip logged after it ended is never celebrated. It is due when the last
/// leg arrives, while the app is open or within two hours of it, and is shown once.
@MainActor
@Observable
final class ArrivalWatcher {
    private(set) var pending: ArrivalMoment?
    @ObservationIgnored private var legs: [Leg] = []
    @ObservationIgnored private var lastFetch: Double = 0

    private static let watchKey = "clack.arrivalWatch"
    private static let shownKey = "clack.arrivalShown"
    private static let cap = 200

    private static func read(_ key: String) -> Set<String> { Set(UserDefaults.standard.stringArray(forKey: key) ?? []) }
    private static func add(_ id: String, to key: String) {
        var all = UserDefaults.standard.stringArray(forKey: key) ?? []
        guard !all.contains(id) else { return }
        all.append(id)
        UserDefaults.standard.set(Array(all.suffix(cap)), forKey: key)
    }

    private static func nowMs() -> Double { Date.now.timeIntervalSince1970 * 1000 }

    /// Runs while the app is in the foreground: keeps the legs fresh, merges live ticks and checks every 30 s.
    func run(_ app: AppModel) async {
        #if DEBUG
        if let at = CommandLine.arguments.firstIndex(of: "-arrival"), at + 1 < CommandLine.arguments.count {
            let id = CommandLine.arguments[at + 1]
            pending = ArrivalMoment(legId: id, journeyId: id.hasPrefix("j-") ? id : nil)
            return
        }
        #endif
        await refresh(app)
        let hub = app.live
        let merge = Task { @MainActor [weak self] in
            for await update in hub.updates() {
                guard let self, let index = self.legs.firstIndex(where: { $0.id == update.legId }) else { continue }
                self.legs[index].live = update.live
                self.evaluate()
            }
        }
        defer { merge.cancel() }
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(30))
            if Task.isCancelled { break }
            let now = Self.nowMs()
            let near = ArrivalLogic.finalLegs(legs).contains { leg in
                guard let arr = TripsLogic.expected(leg).arr else { return false }
                return abs(arr - now) < 15 * 60_000
            }
            if now - lastFetch > (near ? 30_000 : 120_000) { await refresh(app) } else { evaluate() }
        }
    }

    func refresh(_ app: AppModel) async {
        if let fresh = try? await app.client.legs() {
            legs = fresh
            // The trip card (Live Activity): start one for a trip about to leave, end the ones that are over.
            let manager = LiveActivityManager.shared
            for leg in fresh { manager.start(for: leg, enabled: app.settings.notify, client: app.client) }
            await manager.endFinished(legs: fresh)
        }
        lastFetch = Self.nowMs()
        evaluate()
    }

    private func evaluate() {
        let now = Self.nowMs()
        for id in ArrivalLogic.toWatch(legs, now: now) { Self.add(id, to: Self.watchKey) }
        guard pending == nil,
              let leg = ArrivalLogic.due(legs, now: now, watched: Self.read(Self.watchKey), shown: Self.read(Self.shownKey))
        else { return }
        pending = ArrivalMoment(legId: leg.id, journeyId: leg.journeyId)
    }

    /// The screen is up: it won't come again for this journey.
    func markShown(_ moment: ArrivalMoment) {
        Self.add(moment.legId, to: Self.shownKey)
    }

    func dismiss() {
        pending = nil
        evaluate()
    }
}
