//
//  PassportLogic.swift
//  ClackCore
//

import Foundation

/// What the Passport shows for how much there is to show (owner, 2026-10-25): a welcoming start with nothing yet, an
/// "up next" strip while there are only a few journeys, records once there are enough that they aren't one trip
/// repeated, and the collections in tabs.
public nonisolated enum PassportLogic {
    public enum Stage: Hashable, Sendable {
        /// No journeys: the welcoming start.
        case empty
        /// 1 to 4 journeys: the "up next" strip under the cover card.
        case starting
        /// 5 or more: the whole screen.
        case established
    }

    public static let establishedFromJourneys = 5
    /// Fewer than this and every record tile (longest, earliest, most ridden …) would point at the same trip.
    public static let recordsFromJourneys = 3

    public static func stage(journeys: Int) -> Stage {
        journeys <= 0 ? .empty : journeys < establishedFromJourneys ? .starting : .established
    }

    public static func showsRecords(journeys: Int) -> Bool { journeys >= recordsFromJourneys }

    /// The collections, in the order the chips run.
    public enum CollectionTab: String, CaseIterable, Hashable, Sendable {
        case operators, countries, stations, kinds, trainTypes
    }

    public struct TabCount: Hashable, Sendable {
        public let tab: CollectionTab
        public let count: Int
    }

    /// The tabs that have something in them, with how much; an empty collection (no train types known) is left out.
    public static func collectionTabs(operators: Int, countries: Int, stations: Int, kinds: Int, trainTypes: Int) -> [TabCount] {
        let counts: [CollectionTab: Int] = [.operators: operators, .countries: countries, .stations: stations, .kinds: kinds, .trainTypes: trainTypes]
        return CollectionTab.allCases.compactMap { tab in counts[tab].flatMap { $0 > 0 ? TabCount(tab: tab, count: $0) : nil } }
    }

    /// How many more it takes to reach `target` from `value`: the rest of a distance counts as one more, never zero
    /// for a medal not yet won.
    public static func toGo(value: Double?, target: Double) -> Int {
        max(1, Int((target - (value ?? 0)).rounded(.up)))
    }

    public static func toGo(_ milestone: Milestone) -> Int { toGo(value: milestone.value, target: milestone.target) }

    /// The "value" of "value of target" under a locked medal: whole numbers rounded as the cover's are, but never
    /// rounded up to the target it hasn't reached ("1 of 1" under an unearned "Once the length of Sweden"); a fraction
    /// of a small target keeps one decimal ("0,9 of 1").
    public static func progressValue(_ value: Double?, target: Double, language: Language) -> String {
        let v = max(0, value ?? 0)
        if v < target, target <= 10, v.rounded(.down) != v {
            let formatter = NumberFormatter()
            formatter.locale = Format.locale(language)
            formatter.minimumFractionDigits = 1
            formatter.maximumFractionDigits = 1
            formatter.roundingMode = .down
            return formatter.string(from: NSNumber(value: v)) ?? String(v)
        }
        let whole = v.rounded()
        return String(Int(v < target ? min(whole, (target - 1).rounded(.up)) : whole))
    }

    // MARK: milestones, every level

    /// The thresholds per family (mirrors MILESTONES in the server's stats/passport.ts). `kindsOfTrain` is every kind
    /// the server knows (`KINDS_OF_TRAIN.length`, 5 today); a target the server sends that is not here still shows, as
    /// an extra rung (`ladder`), so the app never hides a medal it was given.
    public static func milestoneLevels(_ family: MilestoneFamily) -> [Double] {
        switch family {
        case .journeys: [1, 10, 25, 50, 100, 250, 500, 1000]
        case .distanceKm: [100, 500, 1000, 2500, 5000, 10_000, 40_075, 100_000, 384_400]
        case .stations: [10, 25, 50, 100, 200, 300, 500]
        case .operators: [3, 5, 10, 15, 20]
        case .countries: [2, 3, 5]
        case .borderCrossings, .nightTrains: [1, 5, 10, 25]
        case .longestTrainKm: [300, 500, 1000]
        case .hoursOnBoard: [10, 50, 100, 250, 500, 1000]
        case .trainTypes: [5, 10, 20]
        case .kindsOfTrain: [5]
        case .arcticCircle, .homeLength, .europeLength, .unknown: [1]
        case .earlyBird, .nightOwl: [1, 5, 25]
        case .weekender: [5, 25, 100]
        case .fourSeasons, .capitals, .allNordics: [4]
        case .everyMonth: [12]
        case .streak: [3, 7, 14]
        case .regular: [10, 50, 100]
        case .oresund: [1, 10]
        // Degrees north of 59°N: 8 is 67°N, 9 is 68°N (the server's FAR_NORTH_FROM).
        case .farNorth: [8, 9]
        case .farSouth, .patient: [1]
        case .highSpeedKm: [500, 1000, 5000]
        case .heritage: [1, 5]
        case .longDay: [8, 12]
        case .onTimeRun: [10, 25]
        }
    }

    /// One metal language (owner, 2026-11-14), mirroring MILESTONE_TIERS on the server: bronze is a first step, silver
    /// a regular rider, gold a dedicated one, platinum exceptional. 0 bronze … 3 platinum, one per level.
    public static func milestoneTiers(_ family: MilestoneFamily) -> [Int] {
        switch family {
        case .journeys: [0, 0, 1, 1, 2, 2, 3, 3]
        case .distanceKm: [0, 0, 1, 1, 2, 2, 3, 3, 3]
        case .stations: [0, 1, 1, 2, 2, 3, 3]
        case .operators: [0, 1, 2, 3, 3]
        case .countries, .longestTrainKm, .trainTypes, .earlyBird, .nightOwl, .weekender, .highSpeedKm: [0, 1, 2]
        case .borderCrossings, .nightTrains: [0, 1, 2, 3]
        case .hoursOnBoard: [0, 1, 1, 2, 3, 3]
        case .kindsOfTrain, .arcticCircle, .homeLength, .fourSeasons, .capitals, .allNordics: [2]
        case .europeLength, .everyMonth: [3]
        case .streak, .regular: [1, 2, 3]
        case .oresund: [0, 1]
        case .farNorth, .heritage, .longDay, .onTimeRun: [1, 2]
        case .farSouth: [1]
        case .patient: [0]
        case .unknown: [2]
        }
    }

    /// The tier of one level (0 bronze … 3 platinum); a level the app doesn't list (a newer server) is gold.
    public static func tier(_ m: Milestone) -> Int {
        let levels = milestoneLevels(m.family), tiers = milestoneTiers(m.family)
        guard let i = levels.firstIndex(of: m.target), tiers.indices.contains(i) else { return 2 }
        return tiers[i]
    }

    /// One level of a family: the medal (with the family's current value when locked) and whether it is earned.
    public struct Rung: Hashable, Sendable {
        public let milestone: Milestone
        public let earned: Bool
    }

    public struct FamilyLadder: Hashable, Sendable {
        public let family: MilestoneFamily
        public let rungs: [Rung]
        public var earned: Int { rungs.filter(\.earned).count }
    }

    /// Every family with every level (owner, 2026-11-07: the Milestones screen shows what is still to earn), built from
    /// what the server sends: the medals earned (with their date and trip), every family's current value, and (from
    /// older servers, which send no values) the nearest next ones. A locked level takes the family's value from those;
    /// with none it shows no progress.
    public static func ladder(_ milestones: Passport.Milestones) -> [FamilyLadder] {
        MilestoneFamily.knownCases.map { family in
            let achieved = milestones.achieved.filter { $0.family == family }
            let next = milestones.next.filter { $0.family == family }
            let value: Double? = milestones.values?[family.rawValue] ?? next.compactMap(\.value).max()
                ?? achieved.compactMap(\.value).max() ?? achieved.map(\.target).max()
            let targets = (milestoneLevels(family) + achieved.map(\.target)).reduce(into: [Double]()) { if !$0.contains($1) { $0.append($1) } }.sorted()
            let rungs = targets.map { target -> Rung in
                if let done = achieved.first(where: { $0.target == target }) { return Rung(milestone: done, earned: true) }
                return Rung(milestone: Milestone(family: family, target: target, at: nil, legId: nil, value: value), earned: false)
            }
            return FamilyLadder(family: family, rungs: rungs)
        }
    }

    // MARK: the map, one ink

    /// A stretch of the map and how often it was ridden.
    public struct WeightedRoute: Hashable, Sendable {
        public let geometry: String?
        /// `[lat, lon]` of the first and last stop, when there is no geometry.
        public let stops: [[Double]]
        public let count: Int
    }

    /// The same track ridden many times becomes one line with a weight, so the map can draw it heavier (owner,
    /// 2026-11-07: one ink, thicker where ridden more, instead of operator colours stacking). Two legs are the same
    /// stretch when their lines start and end at the same places (either way round, to about 100 m) and are about as
    /// long; without geometry, when their end stops are the same.
    public static func routeWeights(_ routes: [Passport.MapRoute]) -> [WeightedRoute] {
        var order: [String] = []
        var found: [String: (WeightedRoute, Int)] = [:]
        func place(_ p: LatLon) -> String { "\((p.lat * 1000).rounded())/\((p.lon * 1000).rounded())" }
        for route in routes {
            let key: String
            if let g = route.geometry {
                let points = Polyline.decode(g)
                guard let a = points.first, let b = points.last else { continue }
                let ends = [place(a), place(b)].sorted()
                key = "g|\(ends[0])|\(ends[1])|\(points.count / 20)"
            } else {
                let ends = route.stops.compactMap { $0.count == 2 ? place(LatLon($0[0], $0[1])) : nil }.sorted()
                guard !ends.isEmpty else { continue }
                key = "s|\(ends.joined(separator: "|"))"
            }
            if let (w, _) = found[key] {
                found[key] = (WeightedRoute(geometry: w.geometry, stops: w.stops, count: w.count + 1), 0)
            } else {
                found[key] = (WeightedRoute(geometry: route.geometry, stops: route.stops, count: 1), 0)
                order.append(key)
            }
        }
        return order.compactMap { found[$0]?.0 }
    }
}
