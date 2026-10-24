//
//  AddTrainLogic.swift
//  Clack
//

import Foundation

/// The rules of the Add a train flow (apps/web/src/pages/AddTripPage.tsx; docs/swift-port/SCREENS.md §2.4).
public nonisolated enum AddTrainLogic {
    public static let examples = ["SJ 523", "Stockholm → Göteborg", "Snälltåget Stockholm Malmö"]

    /// Where the destination starts in the text: an arrow, a dash between spaces, "to" or "till", and everything after.
    private static let separator = try? NSRegularExpression(pattern: "\\s*(?:→|->|=>|>|–|—|\\s-\\s|\\bto\\b|\\btill\\b)\\s*.*$", options: .caseInsensitive)

    public enum Filter: String, CaseIterable, Sendable { case all, long, regional, commuter }

    public static func includes(_ result: TripResult, _ filter: Filter) -> Bool {
        switch filter {
        case .all: true
        case .long: ["high_speed", "intercity", "night"].contains(result.product)
        case .regional: ["regional", "heritage"].contains(result.product)
        case .commuter: result.product == "commuter"
        }
    }

    /// The query after picking a station: while typing the destination, everything from the separator is replaced
    /// with " → Name"; otherwise it becomes "[operator ]Name → ".
    public static func query(afterPicking station: StationHit, query: String, interpretation: SearchResponse.Interpretation?) -> String {
        if interpretation?.typing == "to", let separator {
            let range = NSRange(query.startIndex..., in: query)
            return separator.stringByReplacingMatches(in: query, range: range, withTemplate: NSRegularExpression.escapedTemplate(for: " → \(station.name)"))
        }
        return "\(interpretation?.operator.map { "\($0.text) " } ?? "")\(station.name) → "
    }

    /// The query rebuilt from what the search understood, with one part removed.
    public static func rebuilt(operator op: String?, number: String?, from: String?, to: String?) -> String {
        let head = [op, number].compactMap { $0 }.joined(separator: " ")
        let route = (from != nil || to != nil) ? "\(from ?? "") → \(to ?? "")" : ""
        return [head, route].filter { !$0.isEmpty }.joined(separator: " ").trimmingCharacters(in: .whitespaces)
    }

    /// The trip as a search result, from a timetable trip and the stops chosen (for `?trip=` links: defaults to the
    /// first and last stop).
    public static func result(from trip: TimetableTrip, fromSeq: Int?, toSeq: Int?) -> TripResult? {
        guard let first = trip.stops.first, let last = trip.stops.last else { return nil }
        let from = trip.stops.first { $0.seq == fromSeq } ?? first
        let to = trip.stops.first { $0.seq == toSeq } ?? last
        func ref(_ stop: TripStop, _ time: Double?) -> StopRef {
            StopRef(seq: stop.seq, stationId: stop.stationId, name: stop.name, code: stop.code, country: stop.country, tz: stop.tz, time: time ?? 0)
        }
        let dep = (from.dep ?? from.arr)?.ms
        let arr = (to.arr ?? to.dep)?.ms
        return TripResult(
            key: trip.key, serviceDate: trip.serviceDate, trainNumber: trip.trainNumber, operatorId: trip.operatorId,
            category: trip.category, product: trip.product, trainType: trip.trainType, routeName: nil,
            from: ref(from, dep), to: ref(to, arr),
            durationMin: (dep != nil && arr != nil) ? Int(((arr! - dep!) / 60_000).rounded()) : 0,
            stopsBetween: trip.stops.filter { $0.seq > from.seq && $0.seq < to.seq }.count, alsoKnownAs: []
        )
    }

    public enum End: Sendable { case from, to }

    public struct Picked: Equatable, Sendable {
        public var fromSeq: Int
        public var toSeq: Int
        public var picking: End

        public init(fromSeq: Int, toSeq: Int, picking: End) {
            self.fromSeq = fromSeq
            self.toSeq = toSeq
            self.picking = picking
        }
    }

    /// Tapping a stop in the picker. Picking where you got on: it must be before where you got off, and a train can't
    /// be boarded at every stop; then the next tap picks where you got off. Picking where you got off: after where
    /// you got on, and not a stop that doesn't let passengers off. Returns nil when the tap does nothing.
    public static func tap(_ stop: TripStop, in picked: Picked) -> Picked? {
        var next = picked
        switch picked.picking {
        case .from:
            if stop.noPickup || stop.seq >= picked.toSeq { return nil }
            next.fromSeq = stop.seq
            next.picking = .to
        case .to:
            if stop.noDropoff || stop.seq <= picked.fromSeq { return nil }
            next.toSeq = stop.seq
        }
        return next
    }

    /// Whether a stop can become the end being chosen.
    public static func isSelectable(_ stop: TripStop, in picked: Picked) -> Bool {
        picked.picking == .from ? (!stop.noPickup && stop.seq < picked.toSeq) : (!stop.noDropoff && stop.seq > picked.fromSeq)
    }

    public enum Role: Sendable { case from, to, between, outside }

    public static func role(_ stop: TripStop, in picked: Picked) -> Role {
        if stop.seq == picked.fromSeq { return .from }
        if stop.seq == picked.toSeq { return .to }
        return stop.seq > picked.fromSeq && stop.seq < picked.toSeq ? .between : .outside
    }

    public static func haversineM(_ a: (lat: Double, lon: Double), _ b: (lat: Double, lon: Double)) -> Double {
        let r = 6_371_008.8
        let rad = Double.pi / 180
        let x = pow(sin((b.lat - a.lat) * rad / 2), 2) + cos(a.lat * rad) * cos(b.lat * rad) * pow(sin((b.lon - a.lon) * rad / 2), 2)
        return 2 * r * asin(x.squareRoot())
    }

    /// Distance of the ridden part, and whether it is only approximate (no routed geometry, or any estimated segment).
    public static func distance(stops: [TripStop], geometry: TripGeometry?, fromSeq: Int, toSeq: Int) -> (metres: Double, approximate: Bool) {
        let ridden = stops.filter { $0.seq >= fromSeq && $0.seq <= toSeq }
        guard let geometry else {
            var total = 0.0
            for i in ridden.indices.dropFirst() { total += haversineM((ridden[i - 1].lat, ridden[i - 1].lon), (ridden[i].lat, ridden[i].lon)) }
            return (total, true)
        }
        let inside = geometry.segments.filter { $0.fromSeq >= fromSeq && $0.toSeq <= toSeq }
        return (inside.reduce(0) { $0 + $1.lengthM }, inside.contains { $0.estimated })
    }

    /// The route to draw and the parts of the train's route you didn't ride.
    public static func mapRoute(stops: [TripStop], geometry: TripGeometry?, fromSeq: Int, toSeq: Int) -> (route: [LatLon], context: [[LatLon]]) {
        let ridden = stops.filter { $0.seq >= fromSeq && $0.seq <= toSeq }
        guard let geometry else { return (ridden.map { LatLon($0.lat, $0.lon) }, []) }
        func join(_ segments: [TripGeometry.Segment]) -> [LatLon] {
            segments.enumerated().flatMap { i, segment in
                let points = Polyline.decode(segment.polyline)
                return i > 0 ? Array(points.dropFirst()) : points
            }
        }
        let route = join(geometry.segments.filter { $0.fromSeq >= fromSeq && $0.toSeq <= toSeq })
        let before = join(geometry.segments.filter { $0.toSeq <= fromSeq })
        let after = join(geometry.segments.filter { $0.fromSeq >= toSeq })
        return (route, [before, after])
    }

    // MARK: dates

    private static func calendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Stockholm") ?? .gmt
        return calendar
    }

    /// A `YYYY-MM-DD` date as a `Date` at noon in Stockholm (what the date picker shows).
    public static func date(fromIso iso: String) -> Date? {
        let parts = iso.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return calendar().date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2], hour: 12))
    }

    public static func iso(from date: Date) -> String {
        Format.localDate(date.timeIntervalSince1970 * 1000, tz: "Europe/Stockholm")
    }
}
