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

    public var body: some View {
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

    public init(delay: Int?, canceled: Bool = false) {
        self.delay = delay
        self.canceled = canceled
    }
}

/// A line of text whose colour follows the delay band, e.g. an actual time in the stop list. Cancelled is struck
/// through; an estimate is italic.
public struct DelayColoured: ViewModifier {
    public let delay: Int?
    public var canceled = false
    public var estimate = false

    public func body(content: Content) -> some View {
        let band = DelayBand(delayMin: delay, canceled: canceled)
        content
            .foregroundStyle(band.ink)
            .strikethrough(band == .cancelled)
            .italic(estimate)
    }

    public init(delay: Int?, canceled: Bool = false, estimate: Bool = false) {
        self.delay = delay
        self.canceled = canceled
        self.estimate = estimate
    }
}

extension View {
    public func delayColoured(_ delay: Int?, canceled: Bool = false, estimate: Bool = false) -> some View {
        modifier(DelayColoured(delay: delay, canceled: canceled, estimate: estimate))
    }
}
