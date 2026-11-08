//
//  WalkTracker.swift
//  Clack
//

import Foundation

/// Where you are along a station route in walk mode, from the phone's sensors (pure: the app feeds it). The
/// pedometer carries the position along the route's line; a good GPS fix (under 15 m, within 15 m of the line) nudges
/// it 30 % of the way to where the fix says; steps are passed forwards only. A change of level ends when the barometer
/// has risen or fallen 60 % of the floors' measured height difference, when the phone's floor says so, or when you
/// confirm it (offered after the step's time × 1.5). Indoors GPS is ±30 m or worse, so the position is "estimated"
/// whenever there has been no good fix for 20 s.
public nonisolated struct WalkTracker: Sendable {
    public let steps: [RouteGuide.Step]
    /// The step you are on.
    public private(set) var index = 0
    /// Metres into it.
    public private(set) var along = 0.0
    /// When the last good GPS fix came, seconds since 1970.
    public private(set) var lastGoodFix: Double?
    /// A change of level that has taken longer than it should: "Arrived at {level}? Tap to confirm".
    public private(set) var askConfirm = false
    private let heights: [String: Double]
    private let startLevel: String
    private var stepStartedAt: Double
    private var altitudeAtStepStart: Double?
    private var lastAltitude: Double?

    public static let goodFixM = 15.0
    public static let nudge = 0.3
    public static let estimatedAfterS = 20.0
    public static let levelShare = 0.6
    public static let confirmFactor = 1.5

    public init(map: StationMap, route: StationRoute, now: Double) {
        steps = RouteGuide.steps(map, route)
        heights = Dictionary(map.levels.compactMap { l in l.heightM.map { (l.id, $0) } }, uniquingKeysWith: { a, _ in a })
        startLevel = route.nodes.first?.level ?? map.levels.first?.id ?? ""
        stepStartedAt = now
    }

    public var done: Bool { index >= steps.count }
    public var step: RouteGuide.Step? { done ? nil : steps[index] }
    public var isLevelChange: Bool { step.map { $0.key != .walk } ?? false }
    /// The level you are on: the one the last finished step went to.
    public var level: String { index == 0 ? startLevel : steps[index - 1].level }
    /// Metres left in this step.
    public var remaining: Double { max(0, (step?.distanceM ?? 0) - along) }

    /// Where you are and which way the route goes there.
    public var position: (pt: Pt, bearing: Double, level: String)? {
        guard let step else { return steps.last.flatMap { s in s.points.last.map { ($0, RouteGuide.point(along: s.points, at: s.distanceM)?.bearing ?? 0, s.level) } } }
        // During a change of level you are drawn at its foot, on the level you left, until it is done: its footprint
        // runs onto the other level's plan.
        guard let p = RouteGuide.point(along: step.points, at: isLevelChange ? 0 : along) else { return nil }
        return (p.pt, p.bearing, isLevelChange ? level : step.level)
    }

    /// Seconds since the current step began.
    public func stepElapsed(now: Double) -> Double { now - stepStartedAt }

    public func estimated(now: Double) -> Bool {
        guard let lastGoodFix else { return true }
        return now - lastGoodFix > Self.estimatedAfterS
    }

    /// The pedometer counted `meters` more.
    public mutating func walked(_ meters: Double, now: Double) {
        guard meters > 0, !done else { return }
        along += meters
        advance(now: now)
    }

    /// A GPS fix in the map's metres.
    public mutating func fix(_ p: Pt, accuracy: Double, now: Double) {
        guard accuracy > 0, accuracy < Self.goodFixM, let step, step.key == .walk,
              let proj = RouteGuide.project(p, on: step.points), proj.distance <= Self.goodFixM else { return }
        lastGoodFix = now
        along += Self.nudge * (proj.s - along)
        along = max(0, along)
        advance(now: now)
    }

    /// The barometer's altitude relative to where the walk began, metres.
    public mutating func altitude(_ relative: Double, now: Double) {
        lastAltitude = relative
        guard isLevelChange, let step else { return }
        if altitudeAtStepStart == nil { altitudeAtStepStart = relative }
        guard let from = heights[level], let to = heights[step.level], abs(to - from) > 0.5, let start = altitudeAtStepStart else { return }
        // The right way, and far enough: a flat walk never changes the level.
        let moved = (relative - start) * (to > from ? 1 : -1)
        if moved >= Self.levelShare * abs(to - from) { finishStep(now: now) }
    }

    /// The phone's own floor said you are on this level.
    public mutating func reachedLevel(_ id: String, now: Double) {
        if isLevelChange, step?.level == id { finishStep(now: now) }
    }

    /// "Arrived at {level}?" was tapped.
    public mutating func confirmLevel(now: Double) {
        if isLevelChange { finishStep(now: now) }
    }

    /// The clock moved on: offer to confirm a change of level that is taking long.
    public mutating func tick(now: Double) {
        guard let step, step.key != .walk else { askConfirm = false; return }
        askConfirm = now - stepStartedAt > max(step.seconds, 10) * Self.confirmFactor
    }

    private mutating func advance(now: Double) {
        while let step, step.key == .walk, along >= step.distanceM {
            along -= step.distanceM
            finishStep(now: now, carry: along)
        }
        // Within a change of level the walking doesn't finish it (the sensors or a tap do); it stays at its end.
        if let step, step.key != .walk { along = min(along, step.distanceM) }
    }

    private mutating func finishStep(now: Double, carry: Double = 0) {
        index += 1
        along = carry
        stepStartedAt = now
        altitudeAtStepStart = lastAltitude
        askConfirm = false
    }
}
