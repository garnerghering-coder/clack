//
//  ChangeRule.swift
//  ClackCore
//

import Foundation

/// The change rule, the same as the server's (packages/shared/src/changes.ts; both run the same test cases): a change
/// needs the station's tier minimum (hub 15, mid 10, default 7 min) or, between two countries' trains, 10 min (15
/// between Norway and Sweden or Sweden and Finland), whichever is larger, never the sum. Comfort is the spare time over
/// that minimum: risky (below it), tight (under half the minimum spare), normal (up to the minimum spare), relaxed.
/// No walking time: it is only known at the few mapped stations.
public nonisolated enum ChangeRule {
    public static func tierMinimum(_ tier: String?) -> Int {
        switch tier {
        case "hub": 15
        case "mid": 10
        default: 7
        }
    }

    public static func crossBorderMinimum(_ a: String?, _ b: String?) -> Int {
        guard let a, let b, a != b else { return 0 }
        let pair = Set([a, b])
        return pair == ["NO", "SE"] || pair == ["FI", "SE"] ? 15 : 10
    }

    public static func minimum(tier: String?, from a: String?, to b: String?) -> Int {
        max(tierMinimum(tier), crossBorderMinimum(a, b))
    }

    /// History-aware (BUILDOUT O4, the same as packages/shared/src/changes.ts): the incoming train's usual lateness at
    /// the station, the 80th percentile of its arrival delay over the last 28 days, is taken off the gap first, and
    /// only once the record has a week or more of days for it.
    public static let historyMinDays = 7

    public static func typicalLateMin(days: Int, p80Min: Double) -> Int? {
        days >= historyMinDays ? max(0, Int(p80Min.rounded())) : nil
    }

    public static func comfort(gapMin: Int, minMin: Int, typicalLateMin: Int?) -> ChangeComfort {
        comfort(gapMin: gapMin - (typicalLateMin ?? 0), minMin: minMin)
    }

    public static func comfort(gapMin: Int, minMin: Int) -> ChangeComfort {
        let spare = Double(gapMin - minMin)
        if spare < 0 { return .risky }
        if spare < Double(minMin) / 2 { return .tight }
        if spare <= Double(minMin) { return .normal }
        return .relaxed
    }
}
