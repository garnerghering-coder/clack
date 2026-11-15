//
//  StatusText.swift
//  Clack
//

import ClackCore
import SwiftUI

extension DelayBand {
    /// The ink colour for text in this band. Status is written, not boxed: never a pill, never colour alone.
    public var ink: Color {
        switch self {
        case .onTime: Ink.onTimeInk
        case .slight: Ink.slightInk
        case .late: Ink.lateInk
        case .veryLate, .cancelled: Ink.veryLateInk
        case .unknown: Ink.text3
        }
    }

    /// The fill colour for dots and bars.
    public var fill: Color {
        switch self {
        case .onTime: Ink.onTime
        case .slight: Ink.slight
        case .late: Ink.late
        case .veryLate, .cancelled: Ink.veryLate
        case .unknown: Ink.unknown
        }
    }
}

/// `DelayPill`: "On time", "+8", "−2", "Cancelled" or "—", in the band's ink colour (DelayPill.tsx).
public struct DelayText: View {
    @Environment(L10n.self) private var l10n
    public let delay: Int?
    public var canceled = false
    /// Cancelled, with a bus instead (the source says so): written as that, in the late ink rather than the cancelled
    /// red, since there is still a way to get there (owner, 2026-11-07: "are they cancelled, or buses, because that's a
    /// difference?").
    public var replacedByBus = false
    /// "On time" in plain text-2 instead of green, where colour should only mark trouble (a departure board: the
    /// designer counted four colours in one column, 2026-11-07). Delays and cancellations keep their band ink.
    public var mutedOnTime = false

    public var body: some View {
        let band = DelayBand(delayMin: delay, canceled: canceled)
        let quiet = mutedOnTime && band == .onTime
        Text(canceled && replacedByBus ? l10n.t("delay.busReplaced") : label(band))
            .clack(.delay)
            // Trouble in its full ink and bold; a quiet "On time" (a board) in text-2 at medium, so it doesn't compete.
            .fontWeight(quiet ? .medium : band == .unknown ? .semibold : .bold)
            .monospacedDigit()
            // The bus line in the late *ink*: the late fill is too light to read as text on white (designer, build 87).
            .foregroundStyle(canceled && replacedByBus ? Ink.lateInk : (quiet ? Ink.text2 : band.ink))
            .lineLimit(1)
            .fixedSize()
    }

    private func label(_ band: DelayBand) -> String {
        switch band {
        case .cancelled: l10n.t("delay.cancelled")
        case .unknown: l10n.t("delay.unknown")
        default: delay == 0 ? l10n.t("delay.on_time") : Format.delay(delay)
        }
    }

    public init(delay: Int?, canceled: Bool = false, replacedByBus: Bool = false, mutedOnTime: Bool = false) {
        self.delay = delay
        self.canceled = canceled
        self.replacedByBus = replacedByBus
        self.mutedOnTime = mutedOnTime
    }
}
