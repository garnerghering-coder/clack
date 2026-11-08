//
//  WalkPositioner.swift
//  Clack
//

import ClackCore
import CoreLocation
import CoreMotion
import Foundation
import Observation

/// Walk mode's sensors (the same ones the walk recorder uses: `WalkRecorder.startSensors()`), fed into the pure
/// `WalkTracker`: the pedometer's distance, GPS fixes, the compass and the barometer. In Debug
/// builds `simulate` walks the route at 1.3 m/s instead, so the camera, the card and the level changes can be watched
/// without a station.
@MainActor @Observable
final class WalkPositioner: NSObject, CLLocationManagerDelegate {
    private(set) var tracker: WalkTracker
    /// Which way you face, degrees from true north, when the compass is good (better than 30°); else nil.
    private(set) var compass: Double?
    /// How far off the last fix was, metres.
    private(set) var accuracy: Double?
    private(set) var now = Date().timeIntervalSince1970

    private let map: StationMap
    private let location = CLLocationManager()
    private let pedometer = CMPedometer()
    private let altimeter = CMAltimeter()
    private var lastDistance = 0.0
    private var clock: Task<Void, Never>?
    private let simulate: Bool

    static let simulatedSpeed = 1.3

    init(map: StationMap, route: StationRoute, simulate: Bool = false) {
        self.map = map
        self.simulate = simulate
        tracker = WalkTracker(map: map, route: route, now: Date().timeIntervalSince1970)
        super.init()
    }

    /// The heading the view turns to: the compass when it is good, else the way the route goes where you are.
    var heading: Double { compass ?? tracker.position?.bearing ?? 0 }

    func start() {
        let tick = simulateTick
        clock = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(tick))
                guard let self else { return }
                self.now = Date().timeIntervalSince1970
                if self.simulate { self.stepSimulation() }
                self.tracker.tick(now: self.now)
            }
        }
        guard !simulate else { return }
        location.delegate = self
        location.desiredAccuracy = kCLLocationAccuracyBest
        location.distanceFilter = kCLDistanceFilterNone
        location.activityType = .otherNavigation
        location.headingFilter = 2
        location.startUpdatingLocation()
        if CLLocationManager.headingAvailable() { location.startUpdatingHeading() }
        if CMPedometer.isDistanceAvailable() {
            pedometer.startUpdates(from: Date()) { [weak self] data, _ in
                guard let meters = data?.distance?.doubleValue else { return }
                Task { @MainActor in
                    guard let self else { return }
                    let delta = meters - self.lastDistance
                    self.lastDistance = meters
                    self.tracker.walked(delta, now: Date().timeIntervalSince1970)
                }
            }
        }
        if CMAltimeter.isRelativeAltitudeAvailable() {
            altimeter.startRelativeAltitudeUpdates(to: .main) { [weak self] data, _ in
                guard let rel = data?.relativeAltitude.doubleValue else { return }
                MainActor.assumeIsolated { self?.tracker.altitude(rel, now: Date().timeIntervalSince1970) }
            }
        }
    }

    func stop() {
        clock?.cancel()
        location.stopUpdatingLocation()
        location.stopUpdatingHeading()
        pedometer.stopUpdates()
        altimeter.stopRelativeAltitudeUpdates()
    }

    func confirmLevel() { tracker.confirmLevel(now: Date().timeIntervalSince1970) }

    private var simulateTick: Double { simulate ? 0.25 : 1 }

    /// Debug: 1.3 m/s along the route; a change of level takes its own time.
    private func stepSimulation() {
        if tracker.isLevelChange {
            // The stairs, escalator or lift take their own time, then the next level.
            if let step = tracker.step, tracker.stepElapsed(now: now) >= step.seconds { tracker.confirmLevel(now: now) }
            return
        }
        tracker.walked(Self.simulatedSpeed * simulateTick, now: now)
        accuracy = 8
    }

    // MARK: CLLocationManagerDelegate

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let fix = locations.last else { return }
        let (lat, lon, acc) = (fix.coordinate.latitude, fix.coordinate.longitude, fix.horizontalAccuracy)
        // `CLLocation.floor` is not used: it counts from the building's ground floor, and a map's level 0 is its
        // platforms, which are often not the ground floor; a wrong match would switch the level on a flat walk.
        Task { @MainActor in
            self.accuracy = acc
            self.tracker.fix(StationRouting.toLocal(self.map, lat: lat, lon: lon), accuracy: acc, now: Date().timeIntervalSince1970)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        let (accuracy, trueHeading, magnetic) = (newHeading.headingAccuracy, newHeading.trueHeading, newHeading.magneticHeading)
        Task { @MainActor in
            self.compass = accuracy >= 0 && accuracy < 30 ? (trueHeading >= 0 ? trueHeading : magnetic) : nil
        }
    }
}
