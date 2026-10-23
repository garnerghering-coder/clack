//
//  BoardLogic.swift
//  Clack
//

import Foundation

/// Which rows a station board shows (BoardPage.tsx).
nonisolated enum BoardLogic {
    enum Window: String, CaseIterable, Sendable {
        case hour = "1h", threeHours = "3h", day

        var milliseconds: Double {
            switch self {
            case .hour: 3_600_000
            case .threeHours: 3 * 3_600_000
            case .day: 24 * 3_600_000
            }
        }

        /// What "Widen" goes to; nil at the widest.
        var wider: Window? {
            switch self {
            case .hour: .threeHours
            case .threeHours: .day
            case .day: nil
            }
        }
    }

    static let pastMs = 600_000.0
    static let changedRecentMs = 15 * 60_000.0
    static let filterProducts = ["high_speed", "intercity", "regional", "commuter", "night"]

    struct Filter: Sendable {
        var window: Window = .threeHours
        var commuter = true
        var operators: Set<String> = []
        var products: Set<String> = []
        var showEarlier = false
    }

    static func visible(_ rows: [BoardRow], now: Double, filter: Filter) -> [BoardRow] {
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

    /// The platform was changed recently enough to be worth flagging (or when the change happened is unknown).
    static func platformChanged(_ row: BoardRow, now: Double) -> Bool {
        guard let change = row.platformChange else { return false }
        guard let at = change.at else { return true }
        return now - at < changedRecentMs
    }

    /// Past rows (already gone, not cancelled) are dimmed.
    static func isPast(_ row: BoardRow, now: Double) -> Bool { row.shown < now && !row.canceled }
}
