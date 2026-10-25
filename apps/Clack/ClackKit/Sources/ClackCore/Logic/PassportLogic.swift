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
}
