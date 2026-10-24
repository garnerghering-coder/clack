//
//  ProgressBar.swift
//  ClackDesign
//

import SwiftUI

/// A 4 pt bar (radius 2) filled in the operator's colour: how far along a trip is, how far to a milestone, a share
/// of a total. A live trip can add a 14 pt marker at the front: solid with a white ring for a live position, hollow
/// for an estimate. `previous` shows where it was before, faintly (a milestone that moved). The marker and fill glide
/// to a new value; with Reduce Motion they jump.
public struct ProgressBar: View {
    public enum Marker: Sendable { case solid, hollow }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    public let value: Double
    public var color: Color
    public var previous: Double?
    public var marker: Marker?
    /// Fill to `value` from `previous` when it first appears (a milestone filling up).
    public var animateIn = false
    @State private var shown: Double?

    public static let height: CGFloat = 4
    public static let markerSize: CGFloat = 14

    public init(value: Double, color: Color = Ink.accent, previous: Double? = nil, marker: Marker? = nil, animateIn: Bool = false) {
        self.value = value
        self.color = color
        self.previous = previous
        self.marker = marker
        self.animateIn = animateIn
    }

    public var body: some View {
        let target = Self.clamp(value)
        let drawn = shown ?? (animateIn && !reduceMotion ? Self.clamp(previous ?? 0) : target)
        GeometryReader { proxy in
            let w = proxy.size.width
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: Radius.bar, style: .continuous).fill(Ink.hairline)
                if let previous {
                    RoundedRectangle(cornerRadius: Radius.bar, style: .continuous).fill(color.opacity(0.35)).frame(width: w * Self.clamp(previous))
                }
                RoundedRectangle(cornerRadius: Radius.bar, style: .continuous).fill(color).frame(width: w * drawn)
                if let marker {
                    Circle()
                        .fill(marker == .hollow ? Ink.bg : color)
                        .overlay(Circle().strokeBorder(marker == .hollow ? color : Ink.markerRing, lineWidth: 2))
                        .frame(width: Self.markerSize, height: Self.markerSize)
                        .offset(x: w * drawn - Self.markerSize / 2)
                }
            }
            .frame(height: Self.height)
            .frame(maxHeight: .infinity, alignment: .center)
        }
        .frame(height: marker == nil ? Self.height : Self.markerSize)
        .animation(reduceMotion ? nil : (animateIn ? .timingCurve(0.2, 0.8, 0.2, 1, duration: 1.1) : .linear(duration: 1)), value: drawn)
        .task(id: target) {
            guard animateIn, !reduceMotion, shown == nil else { shown = target; return }
            try? await Task.sleep(for: .milliseconds(300))
            shown = target
        }
        .accessibilityElement(children: .ignore)
        .accessibilityValue("\(Int((target * 100).rounded()))%")
    }

    static func clamp(_ v: Double) -> Double { max(0, min(1, v.isFinite ? v : 0)) }
}

/// Shares of a whole in one 4 pt bar (radius 2), each segment in its own colour with a 2 pt gap; a segment never
/// narrower than 6 pt so a small share still shows (the Passport's delay bands).
public struct SegmentedBar: View {
    public struct Segment: Identifiable, Sendable {
        public var id: String
        public var count: Int
        public var color: Color

        public init(id: String, count: Int, color: Color) {
            self.id = id
            self.count = count
            self.color = color
        }
    }

    public let segments: [Segment]

    public init(segments: [Segment]) {
        self.segments = segments.filter { $0.count > 0 }
    }

    public var body: some View {
        let total = max(1, segments.reduce(0) { $0 + $1.count })
        GeometryReader { proxy in
            let room = proxy.size.width - CGFloat(max(0, segments.count - 1)) * 2
            HStack(spacing: 2) {
                ForEach(segments) { s in
                    Rectangle().fill(s.color).frame(width: max(6, room * Double(s.count) / Double(total)))
                }
            }
        }
        .frame(height: ProgressBar.height)
        .clipShape(RoundedRectangle(cornerRadius: Radius.bar, style: .continuous))
        .accessibilityHidden(true)
    }
}
