//
//  LocationModel.swift
//  Clack
//

import CoreLocation
import Foundation
import Observation

/// Where the phone is, for the maps (owner, 2026-10-25): your dot on Explore, and "you" moving along the walk on a
/// station map. When-in-use only, asked the first time something needs it (iOS's own prompt), and running only while a
/// screen that shows it is open (`start`/`stop`, counted, so two screens can share it).
@MainActor
@Observable
final class LocationModel: NSObject, CLLocationManagerDelegate {
    static let shared = LocationModel()

    private(set) var authorization: CLAuthorizationStatus
    private(set) var location: CLLocation?
    /// iOS lets the person share only an approximate position.
    private(set) var reducedAccuracy = false

    @ObservationIgnored private let manager = CLLocationManager()
    @ObservationIgnored private var users = 0
    @ObservationIgnored private var waiting: [CheckedContinuation<CLLocation?, Never>] = []

    override init() {
        authorization = manager.authorizationStatus
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.activityType = .otherNavigation
        reducedAccuracy = manager.accuracyAuthorization == .reducedAccuracy
    }

    var allowed: Bool { authorization == .authorizedWhenInUse || authorization == .authorizedAlways }
    var denied: Bool { authorization == .denied || authorization == .restricted }

    /// Starts following the position (asking first if iOS hasn't been asked). Pair with `stop()`.
    func start() {
        users += 1
        if authorization == .notDetermined { manager.requestWhenInUseAuthorization() }
        if allowed { manager.startUpdatingLocation() }
    }

    func stop() {
        users = max(0, users - 1)
        if users == 0 { manager.stopUpdatingLocation() }
    }

    /// For walking a station: when only an approximate position is shared, asks once for the precise one (iOS's prompt,
    /// with the reason in Info.plist's `NSLocationTemporaryUsageDescriptionDictionary`, key "StationWalk").
    func askPreciseForWalking() {
        guard allowed, reducedAccuracy else { return }
        manager.requestTemporaryFullAccuracyAuthorization(withPurposeKey: "StationWalk")
    }

    /// One fix (asking first if needed), within 12 s, else nil. A fresh known position (under a minute old) is used as it is.
    func current() async -> CLLocation? {
        if let location, -location.timestamp.timeIntervalSinceNow < 60 { return location }
        if denied { return nil }
        if authorization == .notDetermined { manager.requestWhenInUseAuthorization() } else { manager.requestLocation() }
        return await withCheckedContinuation { continuation in
            waiting.append(continuation)
            Task { @MainActor [weak self] in
                try? await Task.sleep(for: .seconds(12))
                self?.resolve(nil)
            }
        }
    }

    private func resolve(_ location: CLLocation?) {
        let all = waiting
        waiting = []
        for c in all { c.resume(returning: location) }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        let reduced = manager.accuracyAuthorization == .reducedAccuracy
        Task { @MainActor in
            authorization = status
            reducedAccuracy = reduced
            if allowed {
                if users > 0 { manager.startUpdatingLocation() }
                if !waiting.isEmpty { manager.requestLocation() }
            } else if denied {
                resolve(nil)
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let best = locations.last else { return }
        Task { @MainActor in
            location = best
            resolve(best)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in resolve(nil) }
    }
}
