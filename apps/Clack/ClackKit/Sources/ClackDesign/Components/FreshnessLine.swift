//
//  FreshnessLine.swift
//  ClackDesign
//

import ClackCore
import SwiftUI

/// "Updated 2 min ago" under data that came from the phone's saved copy or an earlier fetch, so old data is never
/// passed off as fresh (polish pass 1, DECISIONS C7). Past 90 minutes it gives the clock time; past a day, the date.
/// It redraws itself once a minute. `failed` adds "Couldn't refresh" in front, for a refresh that didn't reach the
/// server while the saved data stays on screen.
public struct FreshnessLine: View {
    let updatedAt: Double
    var failed: Bool
    var tz: String
    var clock: ClockFormat
    @Environment(L10n.self) private var l10n

    /// `updatedAt` in ms since 1970.
    public init(updatedAt: Double, failed: Bool = false, tz: String = TimeZone.current.identifier, clock: ClockFormat = .h24) {
        self.updatedAt = updatedAt
        self.failed = failed
        self.tz = tz
        self.clock = clock
    }

    public var body: some View {
        TimelineView(.everyMinute) { context in
            Text(text(now: context.date.timeIntervalSince1970 * 1000))
                .clack(.caption)
                .monospacedDigit()
                .foregroundStyle(failed ? Ink.warnText : Ink.text2)
                .contentTransition(.numericText())
        }
    }

    func text(now: Double) -> String {
        let age = now - updatedAt
        let when: String
        if age < 90 * 60_000 {
            when = l10n.t("live.updated", ["ago": LiveRules.ago(l10n, then: updatedAt, now: now)])
        } else if age < 20 * 3_600_000 {
            when = l10n.t("common.updatedAt", ["time": Format.time(updatedAt, tz: tz, clock: clock)])
        } else {
            when = l10n.t("common.updatedAt", ["time": Format.day(updatedAt, tz: tz, now: now, language: l10n.language)])
        }
        return failed ? Format.join([l10n.t("common.couldntRefresh"), when]) : when
    }
}
