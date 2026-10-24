//
//  TripCardLogic.swift
//  Clack
//

import Foundation

/// The rules for the trip card (Live Activity) on the phone, kept the same as the server's (apps/server/src/push/
/// notifier.ts and rules.ts, docs/swift-port/API.md 2.13): one card per journey, started from 30 minutes before the leg
/// leaves, moved on to the next leg after a change, and ended only when the whole journey is over. Pure, so it is tested
/// without ActivityKit.
public nonisolated enum TripCard {
    /// A card on the phone, as the rules see it.
    public struct Running: Hashable, Sendable {
        /// The leg it shows now (the content state's `legId`, else the attributes').
        public var legId: String
        public var journeyId: String?
        /// The leg it started on (the attributes').
        public var startLegId: String

        public init(legId: String, journeyId: String?, startLegId: String? = nil) {
            self.legId = legId
            self.journeyId = journeyId
            self.startLegId = startLegId ?? legId
        }

        public var journeyKey: String { TripCard.journeyKey(legId: startLegId, journeyId: journeyId) }
    }

    /// How long before departure a card may start (the server's start rule).
    public static let leadMs: Double = 30 * 60_000
    /// How long before the next train a finished leg turns into a change (rules.ts momentOf).
    public static let changeWindowMs: Double = 60 * 60_000
    /// "Get off soon": the last ten minutes before the stop.
    public static let getOffMs: Double = 10 * 60_000

    /// One key per journey (a leg on its own is its own journey).
    public static func journeyKey(legId: String, journeyId: String?) -> String {
        journeyId.map { "j:\($0)" } ?? "l:\(legId)"
    }

    public static func journeyKey(_ leg: Leg) -> String { journeyKey(legId: leg.id, journeyId: leg.journeyId) }

    /// Running, or leaving within 30 minutes; not cancelled and not arrived.
    public static func isDue(_ leg: Leg, now: Double) -> Bool {
        guard !leg.canceled, leg.actualArr == nil, leg.origin != nil, leg.destination != nil else { return false }
        let times = TripsLogic.expected(leg)
        guard let dep = times.dep, let arr = times.arr else { return false }
        return dep - now <= leadMs && arr > now
    }

    /// The card is about the same journey as this leg.
    public static func sameJourney(_ leg: Leg, _ card: Running) -> Bool {
        if let journey = leg.journeyId, journey == card.journeyId { return true }
        return leg.id == card.legId || leg.id == card.startLegId
    }

    /// The legs to start a card for now: at most one per journey (the earliest due leg), none for a journey that has a
    /// card on the phone, and none for a journey that had one already (`started`: so a card the person swiped away
    /// doesn't come back, as on the server).
    public static func toStart(_ legs: [Leg], running: [Running], started: Set<String>, now: Double) -> [Leg] {
        var chosen = Set<String>()
        var result: [Leg] = []
        for leg in legs.sorted(by: { ($0.schedDep?.ms ?? 0) < ($1.schedDep?.ms ?? 0) }) where isDue(leg, now: now) {
            let key = journeyKey(leg)
            if started.contains(key) || chosen.contains(key) || running.contains(where: { sameJourney(leg, $0) }) { continue }
            chosen.insert(key)
            result.append(leg)
        }
        return result
    }

    /// The legs of the card's journey, in order.
    public static func journeyLegs(_ card: Running, legs: [Leg]) -> [Leg] {
        let found = card.journeyId.map { id in legs.filter { $0.journeyId == id } } ?? legs.filter { $0.id == card.legId }
        return found.sorted { ($0.schedDep?.ms ?? 0) < ($1.schedDep?.ms ?? 0) }
    }

    /// The journey is over, so the card can end: the leg it shows is cancelled, the last leg has arrived, or every leg
    /// has arrived or is cancelled. A journey none of whose legs is in the list any more (deleted) is over too. Until
    /// then a card stays, through a change (the server moves it to the next leg).
    public static func isFinished(_ card: Running, legs: [Leg]) -> Bool {
        let journey = journeyLegs(card, legs: legs)
        guard let last = journey.last else { return true }
        if let current = legs.first(where: { $0.id == card.legId }), current.canceled { return true }
        if last.actualArr != nil { return true }
        return journey.allSatisfy { $0.actualArr != nil || $0.canceled }
    }

    /// The leg after this one in its journey (wherever it leaves from).
    public static func after(_ leg: Leg, legs: [Leg]) -> Leg? {
        guard let journey = leg.journeyId else { return nil }
        let arr = leg.schedArr?.ms ?? 0
        return legs
            .filter { $0.journeyId == journey && $0.id != leg.id && ($0.schedDep?.ms ?? 0) >= arr }
            .min { ($0.schedDep?.ms ?? 0) < ($1.schedDep?.ms ?? 0) }
    }

    /// The moment the trip is in: a port of the server's `momentOf` (rules.ts), without the platform-change note (the
    /// phone doesn't know when a platform changed).
    public static func moment(_ leg: Leg, next: Leg?, now: Double) -> (phase: String, changePlatform: String?, changeAt: Double?) {
        if leg.canceled { return ("cancelled", nil, nil) }
        if leg.actualArr != nil {
            if let next, !next.canceled, next.actualDep == nil, let dep = TripsLogic.expected(next).dep, dep > now, dep - now <= changeWindowMs {
                return ("changing", next.depPlatform, dep)
            }
            return ("arrived", nil, nil)
        }
        switch leg.live?.status {
        case .boarding: return ("boarding", nil, nil)
        case .approaching: return ("approaching", nil, nil)
        case .enRoute, .atStop:
            let eta = leg.live?.eta?.ms
            let soon = leg.live?.nextStopId == leg.destStationId && eta.map { $0 - now >= 0 && $0 - now <= getOffMs } == true
            return (soon ? "getOffSoon" : "enRoute", nil, nil)
        default:
            let dep = TripsLogic.expected(leg).dep
            return (dep.map { $0 - now <= leadMs } == true ? "leaveSoon" : "scheduled", nil, nil)
        }
    }

    /// The leg the card shows now: the server's rule (notifier.ts `pushActivity`): an arrived leg with no change to make
    /// moves on to the next leg of the journey.
    public static func currentLeg(_ card: Running, legs: [Leg], now: Double) -> Leg? {
        guard var leg = legs.first(where: { $0.id == card.legId }) else { return nil }
        var seen: Set<String> = [leg.id]
        while moment(leg, next: TripsLogic.nextInJourney(legs, after: leg), now: now).phase == "arrived",
              let next = after(leg, legs: legs), seen.insert(next.id).inserted {
            leg = next
        }
        return leg
    }

    /// What the card shows for a leg, built on the phone: the same fields as the server's `state` (notifier.ts), from
    /// what the app knows. The next stop is named only when it is one of the leg's own ends (the only names a leg
    /// carries); otherwise it is left out rather than guessed.
    public static func state(for leg: Leg, legs: [Leg], now: Double) -> TripCardState? {
        guard let origin = leg.origin, let destination = leg.destination else { return nil }
        let times = TripsLogic.expected(leg)
        let m = moment(leg, next: TripsLogic.nextInJourney(legs, after: leg), now: now)
        let departed = leg.actualDep != nil
        let live = leg.live
        let nextStop: String? = switch live?.nextStopId {
        case leg.destStationId?: destination.name
        case leg.originStationId?: origin.name
        default: nil
        }
        return TripCardState(
            status: leg.canceled ? "cancelled" : leg.actualArr != nil ? "arrived" : (live?.status.rawValue ?? "scheduled"),
            delayMin: live?.arrivalDelayMin ?? leg.arrDelayMin,
            nextStop: nextStop,
            nextStopAt: live?.eta?.ms,
            platform: departed ? leg.arrPlatform : leg.depPlatform,
            platformFor: departed ? "arrival" : "departure",
            progress: live?.progress,
            departAt: times.dep,
            arriveAt: times.arr,
            canceled: leg.canceled,
            phase: m.phase,
            note: nil,
            changePlatform: m.changePlatform,
            changeAt: m.changeAt,
            legId: leg.id,
            train: leg.trainNumber,
            from: origin.name,
            to: destination.name,
            fromTz: origin.tz,
            toTz: destination.tz
        )
    }
}
