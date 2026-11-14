//
//  Motion.swift
//  ClackDesign
//

import SwiftUI

/// The app's animation curves (polish pass 1, DECISIONS M1). Springs by default; nothing seen many times a day runs
/// past about 0.35 s; bounce only in the signature moments. With Reduce Motion, movement becomes a short cross-fade
/// (`reduced`) and the split-flap an instant swap.
public enum Motion: Sendable {
    /// Touch feedback: a press, a toggle, a segment's thumb.
    case tap
    /// Layout changes: a row removed or added, a section opening.
    case layout
    /// Something arriving on screen: a toast, a sheet's content, a state swap.
    case appear
    /// The signature moments only (a card landing, a stamp): a little bounce.
    case signature

    public var animation: Animation {
        switch self {
        case .tap: .snappy(duration: 0.2)
        case .layout: .smooth(duration: 0.3)
        case .appear: .smooth(duration: 0.35)
        case .signature: .spring(duration: 0.45, bounce: 0.25)
        }
    }

    /// The cross-fade used instead when Reduce Motion is on.
    public static let reduced: Animation = .easeInOut(duration: 0.2)

    /// The animation to use, given the Reduce Motion setting. `tap` has none under Reduce Motion (a press shows by
    /// colour alone).
    public func animation(reduceMotion: Bool) -> Animation? {
        guard reduceMotion else { return animation }
        return self == .tap ? nil : Motion.reduced
    }

    /// The split-flap: each half of a tile turns in this long, and the next changed tile starts this much later. Five
    /// digits take about 0.3 s (DESIGN §10, shortened in polish pass 1).
    public static let flapHalf: Double = 0.09
    public static let flapStagger: Double = 0.03

    /// The transition for something that comes and goes: moving from `edge` and fading, or only fading with Reduce
    /// Motion.
    public static func transition(from edge: Edge, reduceMotion: Bool) -> AnyTransition {
        reduceMotion ? .opacity : .move(edge: edge).combined(with: .opacity)
    }
}

private struct MotionModifier<V: Equatable>: ViewModifier {
    let motion: Motion
    let value: V
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content.animation(motion.animation(reduceMotion: reduceMotion), value: value)
    }
}

extension View {
    /// Animates changes caused by `value` only (never the whole view on any refresh), with Reduce Motion respected.
    public func motion<V: Equatable>(_ motion: Motion, value: V) -> some View {
        modifier(MotionModifier(motion: motion, value: value))
    }
}

/// `withAnimation` with a Motion token and the Reduce Motion setting (read it from the environment in the view).
@MainActor
public func withMotion<Result>(_ motion: Motion, reduceMotion: Bool, _ body: () throws -> Result) rethrows -> Result {
    try withAnimation(motion.animation(reduceMotion: reduceMotion), body)
}
