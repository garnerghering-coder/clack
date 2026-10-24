//
//  BoardLogic.swift
//  Clack
//

import Foundation

/// Which rows a station board shows (BoardPage.tsx).
public nonisolated enum BoardLogic {
    public enum Window: String, CaseIterable, Sendable {
        case hour = "1h", threeHours = "3h", day

        public var milliseconds: Double {
            switch self {
            case .hour: 3_600_000
            case .threeHours: 3 * 3_600_000
            case .day: 24 * 3_600_000
            }
        }

        /// What "Widen" goes to; nil at the widest.
        public var wider: Window? {
            switch self {
            case .hour: .threeHours
            case .threeHours: .day
            case .day: nil
            }
        }
    }

    public static let pastMs = 600_000.0
    public static let changedRecentMs = 15 * 60_000.0
    public static let filterProducts = ["high_speed", "intercity", "regional", "commuter", "night"]

    public struct Filter: Sendable {
        public var window: Window = .threeHours
        public var commuter = true
        public var operators: Set<String> = []
        public var products: Set<String> = []
        public var showEarlier = false

        public init(window: Window = .threeHours, commuter: Bool = true, operators: Set<String> = [], products: Set<String> = [], showEarlier: Bool = false) {
            self.window = window
            self.commuter = commuter
            self.operators = operators
            self.products = products
            self.showEarlier = showEarlier
        }
    }

    public static func visible(_ rows: [BoardRow], now: Double, filter: Filter) -> [BoardRow] {
        rows.filter { row in
            if !filter.showEarlier {
                if row.shown < now - pastMs && !row.canceled { return false }
                if row.canceled && row.advertised < now - pastMs { return false }
            }
            if row.advertised > now + filter.window.milliseconds { return false }
            if !filter.commuter && row.product == "commuter" { return false }
            if !filter.operators.isEmpty && !(row.operatorId.map(filter.operators.contains) ?? false) { return false }
            if !filter.products.isEmpty && !filter.products.contains(row.product) { return false }
            return true
        }
    }

    /// The rows to show: the ones that pass the filter and lie within `reach` of now, in time order and without
    /// repeats, the first `limit` of them, and whether there are more behind them.
    public static func page(_ rows: [BoardRow], now: Double, filter: Filter, limit: Int, reach: Double) -> (shown: [BoardRow], more: Bool) {
        var seen = Set<String>()
        let all = visible(rows, now: now, filter: filter)
            .filter { $0.advertised <= now + reach && seen.insert($0.id).inserted }
            .sorted { $0.advertised < $1.advertised }
        return (Array(all.prefix(limit)), all.count > limit)
    }

    /// The platform was changed recently enough to be worth flagging (or when the change happened is unknown).
    public static func platformChanged(_ row: BoardRow, now: Double) -> Bool {
        guard let change = row.platformChange else { return false }
        guard let at = change.at else { return true }
        return now - at < changedRecentMs
    }

    /// Past rows (already gone, not cancelled) are dimmed.
    public static func isPast(_ row: BoardRow, now: Double) -> Bool { row.shown < now && !row.canceled }
}
