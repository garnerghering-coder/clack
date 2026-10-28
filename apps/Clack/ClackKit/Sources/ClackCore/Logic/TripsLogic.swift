//
//  TripsLogic.swift
//  Clack
//

import Foundation

/// The rules behind the Trips screen: what counts as upcoming, which trip is featured, when two trips meet, and the
/// transfer between them (apps/web/src/pages/TripsPage.tsx, components/Journey.tsx, components/Connection.tsx).
/// Times are epoch milliseconds.
public nonisolated enum TripsLogic {
    /// How long after arriving a trip stays featured (as "arrived", with its Passport link) when nothing is ahead.
    public static let recentArrivalMs: Double = 6 * 3_600_000

    public static func tz(_ leg: Leg) -> String { Format.zone(leg.origin?.tz) }

    /// A late train that is still running counts as upcoming until it actually arrives.
    public static func arrivalOf(_ leg: Leg) -> Double {
        if let actual = leg.actualArr?.ms { return actual }
        let estimate = LiveRules.isLive(leg.live) ? (leg.live?.arrivalEta?.ms ?? 0) : 0
        return max(leg.schedArr?.ms ?? 0, estimate)
    }

    /// Best-known departure and arrival: actual, else the live estimate, else the timetable shifted by the known delay.
    public static func expected(_ leg: Leg) -> (dep: Double?, arr: Double?) {
        let dep = leg.schedDep?.ms
        let arr = leg.schedArr?.ms
        return (
            leg.actualDep?.ms ?? dep.map { $0 + Double(leg.depDelayMin ?? 0) * 60_000 },
            leg.actualArr?.ms ?? leg.live?.arrivalEta?.ms ?? arr.map { $0 + Double(leg.arrDelayMin ?? 0) * 60_000 }
        )
    }

    /// Upcoming (arrival still ahead), soonest first; past, most recent first. A trip you said you didn't take is in
    /// neither (owner, 2026-10-25: "it just shouldn't be there"); its page still opens from a link, with Undo.
    public static func partition(_ legs: [Leg], now: Double) -> (upcoming: [Leg], past: [Leg]) {
        let legs = taken(legs)
        let upcoming = legs.filter { arrivalOf($0) > now }.sorted { ($0.schedDep?.ms ?? 0) < ($1.schedDep?.ms ?? 0) }
        let past = legs.filter { arrivalOf($0) <= now }.sorted { ($0.schedDep?.ms ?? 0) > ($1.schedDep?.ms ?? 0) }
        return (upcoming, past)
    }

    /// The trips you didn't say you skipped.
    public static func taken(_ legs: [Leg]) -> [Leg] { legs.filter { $0.ride != .notTaken } }

    public enum HeroState: Sendable { case upcoming, active, arrived }

    /// The featured trip (brief §5.2): the train you're on, else the next departure, else one that arrived in the last
    /// hours.
    public static func hero(upcoming: [Leg], past: [Leg], now: Double) -> (leg: Leg, state: HeroState)? {
        let active = upcoming.first { Landing.isActive(Landing.LegTimes($0), now: now) }
        if let active { return (active, .active) }
        if let first = upcoming.first { return (first, .upcoming) }
        if let recent = past.first(where: { !$0.canceled && now - arrivalOf($0) < recentArrivalMs }) { return (recent, .arrived) }
        return nil
    }

    /// Do these two trips meet: off one and onto the next at the same station, within half a day?
    public static func meets(_ a: Leg, _ b: Leg) -> Bool {
        guard let destination = a.destination, destination.id == b.origin?.id else { return false }
        guard let arr = a.actualArr?.ms ?? a.schedArr?.ms, let dep = b.schedDep?.ms else { return false }
        return dep - arr < 12 * 3_600_000 && dep - arr > -2 * 3_600_000
    }

    /// The leg you change to after this one, if they're one journey and meet at the same station.
    public static func nextInJourney(_ legs: [Leg], after leg: Leg) -> Leg? {
        guard let journeyId = leg.journeyId else { return nil }
        let arr = leg.schedArr?.ms ?? 0
        return legs
            .filter { $0.journeyId == journeyId && $0.id != leg.id && ($0.schedDep?.ms ?? 0) >= arr && $0.origin?.id == leg.destination?.id }
            .sorted { ($0.schedDep?.ms ?? 0) < ($1.schedDep?.ms ?? 0) }
            .first
    }

    public struct MonthGroup: Hashable, Sendable {
        public let label: String
        /// Each item is one trip, or the several trips of one journey in travel order.
        public var items: [[Leg]]

        public init(label: String, items: [[Leg]]) {
            self.label = label
            self.items = items
        }
    }

    /// Legs grouped by journey, each group in travel order; the groups keep the order of their first leg in `legs`
    /// (a journey is one item, not its trips scattered: owner, 2026-10-25).
    public static func journeys(_ legs: [Leg]) -> [[Leg]] {
        var byJourney: [String: [Leg]] = [:]
        for leg in legs { if let id = leg.journeyId { byJourney[id, default: []].append(leg) } }
        var items: [[Leg]] = []
        var done = Set<String>()
        for leg in legs where !done.contains(leg.id) {
            let together = leg.journeyId.flatMap { byJourney[$0] } ?? [leg]
            let item = together.sorted { ($0.schedDep?.ms ?? 0) < ($1.schedDep?.ms ?? 0) }
            for member in item { done.insert(member.id) }
            items.append(item)
        }
        return items
    }

    /// Every taken leg of the journey a leg belongs to, in travel order (just the leg when it stands alone).
    public static func journey(of leg: Leg, in legs: [Leg]) -> [Leg] {
        guard let id = leg.journeyId else { return [leg] }
        let all = taken(legs).filter { $0.journeyId == id }.sorted { ($0.schedDep?.ms ?? 0) < ($1.schedDep?.ms ?? 0) }
        return all.isEmpty ? [leg] : all
    }

    /// Past trips by month; legs of one journey are shown together, in travel order (DESIGN §4).
    public static func months(_ past: [Leg], language: Language) -> [MonthGroup] {
        var groups: [MonthGroup] = []
        for item in journeys(past) {
            let label = Format.month(item[0].schedDep?.ms ?? 0, tz: tz(item[0]), language: language)
            if groups.last?.label != label { groups.append(MonthGroup(label: label, items: [])) }
            groups[groups.count - 1].items.append(item)
        }
        return groups
    }

    /// The planned transfer between two legs, and whether the real times made it tight or missed (DESIGN §7).
    public struct Transfer: Equatable, Sendable {
        public let planned: Int
        public let actual: Int?
        public let missed: Bool
        public let tight: Bool
        public let station: String

        public init(planned: Int, actual: Int?, missed: Bool, tight: Bool, station: String) {
            self.planned = planned
            self.actual = actual
            self.missed = missed
            self.tight = tight
            self.station = station
        }
    }

    public static func transfer(from prev: Leg, to next: Leg) -> Transfer {
        let planned = Int((((next.schedDep?.ms ?? 0) - (prev.schedArr?.ms ?? 0)) / 60_000).rounded())
        let arrived = prev.actualArr?.ms
        let left = next.actualDep?.ms ?? next.schedDep?.ms
        let missed = arrived != nil && left != nil && arrived! > left!
        let actual = (arrived != nil && left != nil) ? Int(((left! - arrived!) / 60_000).rounded()) : nil
        return Transfer(planned: planned, actual: actual, missed: missed, tight: !missed && (actual ?? planned) < 10, station: prev.destination?.name ?? "")
    }

    /// Best current estimate of when leg A arrives and leg B leaves, and whether both come from real-time data.
    public static func connectionTimes(_ a: Leg, _ b: Leg) -> (arrival: Double?, departure: Double?, live: Bool) {
        let liveArr = a.actualArr?.ms ?? a.live?.arrivalEta?.ms
        let arrival = liveArr ?? a.schedArr.map { $0.ms + Double(a.arrDelayMin ?? 0) * 60_000 }
        // Before it leaves, a live leg's next stop is the one you board at: its ETA is the expected departure.
        let boardingEta: Double? = (b.live?.status == .scheduled || b.live?.status == .boarding) ? b.live?.eta?.ms : nil
        let liveDep = b.actualDep?.ms ?? boardingEta
        let departure = liveDep ?? b.schedDep.map { $0.ms + Double(b.depDelayMin ?? 0) * 60_000 }
        return (arrival, departure, liveArr != nil && liveDep != nil)
    }

    /// The change between two legs at the station they share: the walk from the station map when there is one, else an
    /// estimate from the station's size (docs/swift-port/SCREENS.md §3.6).
    public static func connection(
        _ a: Leg, _ b: Leg, map: StationMap?, info: StationInfo?, profile: WalkProfile
    ) -> (result: ConnectionResult, noPath: Bool) {
        let times = connectionTimes(a, b)
        let route = map.flatMap { StationRouting.routeTracks($0, from: a.arrPlatform, to: b.depPlatform, profile: profile) }
        // A map that can't connect the two platforms falls back to the size estimate (and is a data bug to fix).
        let noPath = map != nil && !(a.arrPlatform ?? "").isEmpty && !(b.depPlatform ?? "").isEmpty && route == nil
        let result = StationRouting.connectionStatus(
            ConnectionInput(
                arrival: times.arrival, departure: times.departure, arrivalPlatform: a.arrPlatform,
                departurePlatform: b.depPlatform, canceledA: a.canceled, canceledB: b.canceled,
                walkSeconds: route.map { Double($0.seconds) }, sizeClass: info?.sizeClass ?? (map != nil ? .large : .medium),
                timesLive: times.live
            )
        )
        var judged = result
        if let arrival = times.arrival, let departure = times.departure {
            let gap = Int(((departure - arrival) / 60_000).rounded(.down))
            let minimum = ChangeRule.minimum(tier: b.originTier, from: a.trainCountry, to: b.trainCountry)
            judged.gapMin = gap
            judged.minMin = minimum
            judged.comfort = a.canceled || b.canceled ? nil : ChangeRule.comfort(gapMin: gap, minMin: minimum)
        }
        return (judged, noPath)
    }

    /// Everything the Layover Guide needs about a change (the web's map link).
    public static func mapLink(_ stationId: String, _ a: Leg, _ b: Leg) -> StationMapLink {
        let times = connectionTimes(a, b)
        return StationMapLink(
            stationId: stationId, from: a.arrPlatform, to: b.depPlatform, arrival: times.arrival, departure: times.departure,
            operatorA: a.operator?.id, operatorB: b.operator?.id, canceledA: a.canceled, canceledB: b.canceled, live: times.live
        )
    }
}
