//
//  MotionTilt.swift
//  Clack
//

import CoreMotion
import SwiftUI

/// How the phone is tilted, for a card that catches the light as you move it (owner, 2026-10-24: the Passport card
/// follows the phone instead of a finger, so the page can scroll under your thumb). Read relative to how the phone was
/// held when the card appeared, smoothed so it glides. Without motion sensors (the simulator) it stays still.
@MainActor
@Observable
final class MotionTilt {
    /// Degrees to rotate the card about the vertical axis (phone rolled left or right) and the horizontal (tipped).
    private(set) var yaw = 0.0
    private(set) var pitch = 0.0
    /// 0 to 1 across the card: where the shine sits.
    private(set) var shine = 0.4

    private let manager = CMMotionManager()
    private var reference: (roll: Double, pitch: Double)?

    func start() {
        guard manager.isDeviceMotionAvailable, !manager.isDeviceMotionActive else { return }
        reference = nil
        manager.deviceMotionUpdateInterval = 1.0 / 30
        manager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let motion else { return }
            MainActor.assumeIsolated { self?.update(roll: motion.attitude.roll, pitch: motion.attitude.pitch) }
        }
    }

    func stop() {
        manager.stopDeviceMotionUpdates()
    }

    private func update(roll: Double, pitch p: Double) {
        let base = reference ?? (roll, p)
        reference = base
        let rad = 180 / Double.pi
        // A few degrees of tilt is enough: the card tips up to 6 degrees about the vertical axis and 5 about the horizontal.
        let targetYaw = ((roll - base.roll) * rad * 0.25).clamped(-6, 6)
        let targetPitch = ((p - base.pitch) * rad * 0.2).clamped(-5, 5)
        let targetShine = (0.5 + (roll - base.roll) * rad / 50).clamped(0, 1)
        // Low-pass: move a fraction of the way each time.
        yaw += (targetYaw - yaw) * 0.18
        pitch += (targetPitch - pitch) * 0.18
        shine += (targetShine - shine) * 0.18
    }
}

private extension Double {
    func clamped(_ lower: Double, _ upper: Double) -> Double { Swift.min(Swift.max(self, lower), upper) }
}
