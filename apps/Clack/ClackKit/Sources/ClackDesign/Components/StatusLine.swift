//
//  StatusLine.swift
//  ClackDesign
//

import ClackCore
import SwiftUI

/// One line of written status (DESIGN §2.3, §9.5): never a box. The kind decides the ink; Live adds an 8 pt dot that
/// pulses in the on-time colour (steady with Reduce Motion). The words come from the caller, already translated.
public struct StatusLine: View {
    public enum Kind: Equatable, Sendable {
        /// Tracked and fresh: the pulsing dot, in the on-time ink.
        case live
        /// Live data that has stopped coming, or old data: grey.
        case stale
        /// Not left yet (a countdown, "Upcoming").
        case upcoming
        /// At the platform, within 30 minutes of leaving.
        case boarding
        /// The train is on its way to where you get on.
        case onItsWay
        /// Done, or a plain fact.
        case arrived
        case cancelled
        /// The phone's own estimate, or an estimated position.
        case estimated
        /// A delay band's ink (a change that is tight, missed or easy).
        case band(DelayBand)
    }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    public let kind: Kind
    public let text: String
    @State private var dim = false

    public init(_ kind: Kind, _ text: String) {
        self.kind = kind
        self.text = text
    }

    public var ink: Color {
        switch kind {
        case .live: Ink.onTimeInk
        case .stale, .estimated: Ink.text3
        case .upcoming, .onItsWay: Ink.accentInk
        case .boarding: Ink.slightInk
        case .arrived: Ink.text2
        case .cancelled: Ink.veryLateInk
        case .band(let band): band.ink
        }
    }

    public var body: some View {
        HStack(spacing: 4) {
            if kind == .live {
                Circle().fill(Ink.onTime).frame(width: 8, height: 8)
                    .opacity(dim ? 0.35 : 1)
                    .animation(reduceMotion ? nil : .easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: dim)
                    .onAppear { if !reduceMotion { dim = true } }
                    .accessibilityHidden(true)
            }
            Text(text).lineLimit(1)
        }
        .clack(.chip)
        .foregroundStyle(ink)
        .accessibilityElement(children: .combine)
    }
}
