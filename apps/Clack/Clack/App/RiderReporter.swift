//
//  RiderReporter.swift
//  Clack
//

import ActivityKit
import ClackCore
import CoreLocation
import Foundation
import Observation
import UIKit

/// The phone placing the train it is on (owner, 2026-10-30; docs/POSITIONING.md "Riders' reports").
///
/// While one of your logged trains is running and the app is open (or that trip's Live Activity runs), every 20 s:
/// the phone's position is snapped onto that train's track (`RiderLogic.snap`). Your own map then draws your train
/// there (nothing leaves the phone for that). With "Help place trains for everyone" on (off by default, kept on this
/// phone only, never on the server), the snapped place goes to the server as a report: train, stretch, how far along,
/// speed, time and a session id random per trip. No coordinates, no user id.
///
/// Location is read only with "While Using" permission, never asked for here (the map asks when it shows your dot).
/// In the background it goes on only while a trip's Live Activity runs, through a background activity session started
/// in the foreground (iOS shows the location indicator), and stops when the train is no longer running.
@MainActor
@Observable
final class RiderReporter {
    static let shared = RiderReporter()

    /// "Help place trains for everyone".
    var sharing: Bool = UserDefaults.standard.bool(forKey: Keys.sharing) {
        didSet { UserDefaults.standard.set(sharing, forKey: Keys.sharing) }
    }
    /// The one-time ask, shown once a logged train is found running with the phone on it.
    var showAsk = false

    private enum Keys {
        static let sharing = "riders.sharing"
        static let asked = "riders.asked"
    }

    /// Where the phone last put each of your trains: its stretch, metres along, speed, when.
    struct Own: Equatable {
        let prevId: String
        let nextId: String
        let alongM: Double
        let speedMps: Double
        let at: Date
    }
    @ObservationIgnored private(set) var own: [String: Own] = [:]
    @ObservationIgnored private var tracks: [String: ExploreLogic.TrackPath] = [:]
    /// Random per train (per trip), never stored.
    @ObservationIgnored private var sessions: [String: String] = [:]
    @ObservationIgnored private var lastSent: [String: Date] = [:]
    @ObservationIgnored private var loop: Task<Void, Never>?
    @ObservationIgnored private var following = false
    @ObservationIgnored private var background: CLBackgroundActivitySession?

    /// Starts the loop if it isn't running (the app came to the front). It ends by itself when there is nothing to do.
    func resume(client: APIClient) {
        guard loop == nil else { return }
        loop = Task { [weak self] in
            await self?.run(client: client)
            self?.loop = nil
        }
    }

    /// Your train drawn where your phone is: carried on along its track from the last fix at its speed, for a minute
    /// at most, never past the next stop. Nil when the phone hasn't placed it.
    func position(of train: LiveTrain, now: Date = Date()) -> (position: LatLon, bearing: Double)? {
        guard let o = own[train.id], o.prevId == train.prevId, o.nextId == train.nextId,
              let track = tracks["\(o.prevId)>\(o.nextId)"] else { return nil }
        let age = now.timeIntervalSince(o.at)
        guard age >= 0, age < 60 else { return nil }
        return track.at(min(track.length, o.alongM + o.speedMps * age))
    }

    private var liveActivityRunning: Bool {
        Activity<TripActivityAttributes>.activities.contains { !LiveActivityManager.isSample($0) && $0.activityState == .active }
    }

    private func run(client: APIClient) async {
        let location = LocationModel.shared
        defer { stopFollowing() }
        while !Task.isCancelled {
            let foreground = UIApplication.shared.applicationState == .active
            guard foreground || liveActivityRunning else { return }
            let running = ((try? await client.liveMine()) ?? []).filter { $0.state == "running" && $0.prevId != nil && $0.nextId != nil }
            if running.isEmpty || !location.allowed {
                stopFollowing()
                // Nothing of yours running: look again in a minute while the app stays open.
                try? await Task.sleep(for: .seconds(60))
                continue
            }
            startFollowing(keepInBackground: liveActivityRunning)
            if let fix = location.location, -fix.timestamp.timeIntervalSinceNow < 30 {
                for train in running { await place(train, fix: fix, client: client) }
            }
            try? await Task.sleep(for: .seconds(RiderLogic.interval))
        }
    }

    private func place(_ train: LiveTrain, fix: CLLocation, client: APIClient) async {
        guard let from = train.prevId, let to = train.nextId else { return }
        let key = "\(from)>\(to)"
        if tracks[key] == nil, let segment = try? await client.liveSegment(from: from, to: to) {
            let points = Polyline.decode(segment.polyline)
            if points.count >= 2 { tracks[key] = ExploreLogic.TrackPath(points: points) }
        }
        guard let track = tracks[key],
              let snap = RiderLogic.snap(fix: LatLon(fix.coordinate.latitude, fix.coordinate.longitude), accuracyM: fix.horizontalAccuracy,
                                         speedMps: fix.speed, track: track, feedProgress: train.progress)
        else { return }
        own[train.id] = Own(prevId: from, nextId: to, alongM: snap.alongM, speedMps: snap.speedKmh / 3.6, at: fix.timestamp)
        if !UserDefaults.standard.bool(forKey: Keys.asked) {
            UserDefaults.standard.set(true, forKey: Keys.asked)
            showAsk = true
        }
        guard sharing else { return }
        if let last = lastSent[train.id], Date().timeIntervalSince(last) < RiderLogic.interval - 1 { return }
        let session = sessions[train.id] ?? UUID().uuidString.lowercased()
        sessions[train.id] = session
        lastSent[train.id] = Date()
        let report = RiderLogic.Report(train: train.id, prevId: from, nextId: to, progress: snap.progress, speedKmh: snap.speedKmh,
                                       at: fix.timestamp.timeIntervalSince1970 * 1000, session: session)
        try? await client.riderReport(report)
    }

    private func startFollowing(keepInBackground: Bool) {
        if !following {
            following = true
            LocationModel.shared.start()
        }
        // Only while a trip's Live Activity runs, and only started from the front (iOS's rule).
        if keepInBackground, background == nil, UIApplication.shared.applicationState == .active {
            background = CLBackgroundActivitySession()
        } else if !keepInBackground {
            background?.invalidate()
            background = nil
        }
    }

    private func stopFollowing() {
        background?.invalidate()
        background = nil
        if following {
            following = false
            LocationModel.shared.stop()
        }
        own = [:]
        sessions = [:]
        lastSent = [:]
    }
}
