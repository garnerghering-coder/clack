//
//  StatusText.swift
//  Clack
//

import SwiftUI

extension DelayBand {
    /// The ink colour for text in this band. Status is written, not boxed: never a pill, never colour alone.
    var ink: Color {
        switch self {
        case .onTime: Ink.onTimeInk
        case .slight: Ink.slightInk
        case .late: Ink.lateInk
        case .veryLate, .cancelled: Ink.veryLateInk
        case .unknown: Ink.text3
        }
    }

    /// The fill colour for dots and bars.
    var fill: Color {
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
struct DelayText: View {
    @Environment(L10n.self) private var l10n
    let delay: Int?
    var canceled = false

    var body: some View {
        let band = DelayBand(delayMin: delay, canceled: canceled)
        Text(label(band))
            .clack(.delay)
            .fontWeight(band == .unknown ? .semibold : .bold)
            .monospacedDigit()
            .foregroundStyle(band.ink)
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
}

/// A line of text whose colour follows the delay band, e.g. an actual time in the stop list. Cancelled is struck
/// through; an estimate is italic.
struct DelayColoured: ViewModifier {
    let delay: Int?
    var canceled = false
    var estimate = false

    func body(content: Content) -> some View {
        let band = DelayBand(delayMin: delay, canceled: canceled)
        content
            .foregroundStyle(band.ink)
            .strikethrough(band == .cancelled)
            .italic(estimate)
    }
}

extension View {
    func delayColoured(_ delay: Int?, canceled: Bool = false, estimate: Bool = false) -> some View {
        modifier(DelayColoured(delay: delay, canceled: canceled, estimate: estimate))
    }
}
