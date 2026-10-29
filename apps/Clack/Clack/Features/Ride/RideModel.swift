//
//  RideModel.swift
//  Clack
//

import ClackCore
import CoreLocation
import CoreMotion
import Foundation
import Observation

/// Which train the Ride view follows. Outside the model so routes can hash it off the main actor.
nonisolated enum RideTarget: Hashable, Sendable {
    /// A train on the live map, by its live id.
    case live(id: String)
    /// A train by number and day (from a trip), looked up on the live map first.
    case train(number: String, date: String, key: String?)
    #if DEBUG
    case replay
    #endif
}

/// What the Ride view knows (BUILDOUT O3): the train (asked for every five seconds), its track and stops, the last
/// position report as metres along the track, the camera preset (remembered), and the phone's own speed and altitude
/// once it is aboard. `-open ride:replay` (Debug) replays a run along a real track instead.
@MainActor
@Observable
final class RideModel {
    typealias Target = RideTarget

    enum Status: Equatable { case loading, running, notRunning, noTrack, failed }

    struct Stop: Equatable {
        var seq: Int
        var name: String
        var eta: Double?
        var passed: Bool
    }

    let target: Target
    private(set) var status = Status.loading
    private(set) var train: LiveTrain?
    private(set) var legId: String?
    private(set) var track: RideLogic.Track?
    private(set) var stops: [Stop] = []
    private(set) var report: RideReport?
    private(set) var title = ""
    private(set) var template = TrainKit.Template.multipleUnit
    private(set) var cars = (count: 4, known: false)
    private(set) var brandColor: String?
    private(set) var tz = "Europe/Stockholm"

    /// The phone's barometric altitude (metres above sea level, CoreMotion's absolute altitude), when it gives one.
    private(set) var altitudeM: Double?

    /// The camera preset and the pinched distance per preset, remembered.
    var preset: RideLogic.CameraPreset {
        didSet { UserDefaults.standard.set(preset.rawValue, forKey: Self.presetKey) }
    }
    private(set) var distances: [String: Double] {
        didSet { UserDefaults.standard.set(distances, forKey: Self.distancesKey) }
    }
    private static let presetKey = "clack.ride.preset"
    private static let distancesKey = "clack.ride.distances"

    @ObservationIgnored private let altimeter = CMAltimeter()
    @ObservationIgnored private var pinchStart: Double?
    private let location = LocationModel.shared

    init(target: Target) {
        self.target = target
        preset = UserDefaults.standard.string(forKey: Self.presetKey).flatMap(RideLogic.CameraPreset.init) ?? .behind
        distances = UserDefaults.standard.dictionary(forKey: Self.distancesKey) as? [String: Double] ?? [:]
    }

    /// The camera orbits the train on a ring (owner, 2026-10-29): dragging turns it round the train and tilts it,
    /// pinching moves it in and out; a preset is a starting point on that ring.
    private(set) var orbitHeading: Double?
    private(set) var orbitPitch: Double?

    var camera: RideLogic.Camera {
        let base = RideLogic.camera(preset, distance: distances[preset.rawValue])
        return RideLogic.Camera(pitch: orbitPitch ?? base.pitch, distance: base.distance, headingOffset: orbitHeading ?? base.headingOffset, lookAheadM: base.lookAheadM)
    }

    /// A drag of `dx`, `dy` points: a screen width turns the camera all the way round; up and down tilts it.
    func orbit(dx: CGFloat, dy: CGFloat, width: CGFloat) {
        let h = (orbitHeading ?? camera.headingOffset) - Double(dx / max(1, width)) * 360
        orbitHeading = (h.truncatingRemainder(dividingBy: 360) + 360).truncatingRemainder(dividingBy: 360)
        orbitPitch = min(80, max(20, (orbitPitch ?? camera.pitch) + Double(dy) * 0.25))
    }

    /// A preset puts the camera back on its own spot of the ring.
    func choose(_ p: RideLogic.CameraPreset) {
        preset = p
        orbitHeading = nil
        orbitPitch = nil
    }

    /// A pinch scales the camera's distance from where it was when the gesture began.
    func pinch(scale: CGFloat, ended: Bool) {
        let start = pinchStart ?? camera.distance
        pinchStart = start
        let d = min(RideLogic.distanceRange.upperBound, max(RideLogic.distanceRange.lowerBound, start / Double(scale)))
        distances[preset.rawValue] = d
        if ended { pinchStart = nil }
    }

    // MARK: what the panel shows

    /// Metres along the track the train is drawn at now (the report extrapolated), and the point there.
    func drawn(now: Double) -> (metres: Double, point: LatLon)? {
        guard let track, let r = report else { return nil }
        let m = min(r.limitM, RideLogic.extrapolate(metres: r.metres, reportedAt: r.at, speedKmh: r.speedKmh, now: now, track: track))
        guard let p = track.point(at: m) else { return nil }
        return (m, p)
    }

    /// The ride counts as under way once the train has left its first stop and until it has reached its last.
    var underWay: Bool {
        guard let r = report else { return false }
        if let last = stops.last, last.passed { return false }
        return r.metres > 30 || (stops.first?.passed ?? false)
    }

    /// The next stop ahead of where the train is drawn.
    func nextStop(now: Double) -> Stop? {
        guard let track, let d = drawn(now: now) else { return nil }
        return stops.filter { !$0.passed && (track.stopsAt[$0.seq] ?? -1) > d.metres + 20 }.min { ($0.seq) < ($1.seq) } ?? stops.last
    }

    /// The speedometer reading now, from the phone when aboard, else the train.
    func speed(now: Double) -> RideLogic.Speed {
        let fix = location.location
        let d = drawn(now: now)
        var phoneDistance: Double?
        if let fix, let d { phoneDistance = fix.distance(from: CLLocation(latitude: d.point.lat, longitude: d.point.lon)) }
        return RideLogic.speed(
            phoneKmh: fix.flatMap { $0.speed >= 0 ? $0.speed * 3.6 : nil },
            phoneAgeS: fix.map { -$0.timestamp.timeIntervalSinceNow },
            phoneDistanceM: phoneDistance,
            trainKmh: train?.speedKmh ?? report?.speedKmh,
            trainEstimated: train?.estimated ?? false,
            trainAgeS: report.map { (now - $0.at) / 1000 } ?? .infinity,
            underWay: underWay
        )
    }

    /// Kilometres and minutes left to the last stop, when both are known.
    func left(now: Double) -> (km: Double, min: Int)? {
        guard let track, let d = drawn(now: now), let last = stops.last, let end = track.stopsAt[last.seq], let eta = last.eta else { return nil }
        return (max(0, end - d.metres) / 1000, max(0, Int(((eta - now) / 60_000).rounded())))
    }

    // MARK: running

    /// Follows the train until cancelled: the first look-up, then the train every 5 s and its stops every 30 s.
    func run(_ app: AppModel) async {
        location.start()
        startAltimeter()
        defer {
            location.stop()
            altimeter.stopAbsoluteAltitudeUpdates()
        }
        #if DEBUG
        if case .replay = target {
            await replay(app)
            return
        }
        #endif
        guard var id = await resolveId(app) else {
            status = .notRunning
            return
        }
        var sinceStops = 100
        while !Task.isCancelled {
            if let detail = try? await app.client.liveTrain(id) {
                id = detail.train.id
                apply(detail, app)
                if track == nil, let trip = detail.trip, let geometry = try? await app.client.timetableTripGeometry(trip.key, date: trip.serviceDate) {
                    let t = RideLogic.Track(geometry: geometry)
                    track = t.points.count >= 2 ? t : nil
                    if track == nil { status = .noTrack }
                }
                if sinceStops >= 6 {
                    sinceStops = 0
                    if let list = try? await app.client.liveTrainStops(id) {
                        stops = list.map { Stop(seq: $0.seq, name: $0.name, eta: $0.estimatedArr ?? $0.actualArr ?? $0.arr ?? $0.estimatedDep ?? $0.dep, passed: $0.passed) }
                        if let first = list.first { tz = Format.zone(stationId: first.stationId) }
                    }
                }
                sinceStops += 1
                updateReport()
            } else if train == nil {
                status = .failed
            }
            try? await Task.sleep(for: .seconds(5))
        }
    }

    private func resolveId(_ app: AppModel) async -> String? {
        switch target {
        case .live(let id): return id
        case .train(let number, let date, let key):
            return (try? await app.client.train(number: number, date: date, key: key))?.live?.id
        #if DEBUG
        case .replay: return nil
        #endif
        }
    }

    private func apply(_ detail: LiveTrainDetail, _ app: AppModel) {
        train = detail.train
        legId = detail.legId
        let t = detail.train
        let op = t.operatorId.flatMap { app.operatorsById[$0] }
        let type = t.trainType.flatMap { id in app.trainTypes.first { $0.id == id } }
        title = [t.productName ?? op?.name, t.number].compactMap { $0 }.joined(separator: " ")
        template = TrainKit.template(forArt: type?.art)
        cars = TrainKit.carCount(live: t.cars, typical: type?.cars, template: template)
        brandColor = op?.brandColor
        if status == .loading || status == .failed { status = track == nil && status != .noTrack ? .loading : .running }
        if track != nil { status = .running }
    }

    /// The train's reported position as metres along the track, with the next stop as the limit it may not pass.
    private func updateReport() {
        guard let track, let t = train else { return }
        let m = RideLogic.metresAlong(track, of: LatLon(t.lat, t.lon))
        let next = track.stopsAt.values.filter { $0 > m + 1 }.min() ?? track.length
        // An estimated position is the server's for now, not for the old fix time. Without a reported speed, the
        // speed is read off the last two reports, so the train keeps moving between them instead of freezing.
        let at = t.estimated ? Date.now.timeIntervalSince1970 * 1000 : t.at.ms
        var speed = t.speedKmh
        if speed == nil, let last = report, at > last.at + 1000, m >= last.metres {
            speed = min(250, (m - last.metres) / ((at - last.at) / 1000) * 3.6)
        }
        if let last = report, last.metres == m, last.at == at { return }
        report = RideReport(metres: m, at: at, speedKmh: speed, limitM: next)
        status = .running
    }

    private func startAltimeter() {
        guard CMAltimeter.isAbsoluteAltitudeAvailable() else { return }
        altimeter.startAbsoluteAltitudeUpdates(to: .main) { [weak self] data, _ in
            guard let data else { return }
            Task { @MainActor in self?.altitudeM = data.altitude }
        }
    }

    #if DEBUG
    private nonisolated struct SegmentAnswer: Decodable, Sendable { let polyline: String }

    /// Stockholm C → Uppsala C at 120 km/h, reports every 5 s, round and round (the proof's run).
    private func replay(_ app: AppModel) async {
        guard let seg: SegmentAnswer = try? await app.client.get(["live", "segment"], query: ["from": "740000001", "to": "740000005"]) else {
            status = .failed
            return
        }
        let points = Polyline.decode(seg.polyline)
        guard points.count >= 2 else {
            status = .noTrack
            return
        }
        let t = RideLogic.Track(points: points, stopsAt: [1: 0, 2: TrainKit.cumulative(points).last ?? 0])
        track = t
        title = "Replay · Stockholm C → Uppsala C"
        template = .highSpeed
        cars = (6, true)
        brandColor = app.operatorsById["sj"]?.brandColor
        status = .running
        let started = Date.now.timeIntervalSince1970 * 1000
        let speed = 120.0
        while !Task.isCancelled {
            let now = Date.now.timeIntervalSince1970 * 1000
            let m = (300 + (now - started) / 1000 * speed / 3.6).truncatingRemainder(dividingBy: max(1, t.length - 400))
            report = RideReport(metres: m, at: now, speedKmh: speed, limitM: t.length)
            let eta = now + (t.length - m) / (speed / 3.6) * 1000
            stops = [Stop(seq: 1, name: "Stockholm C", eta: nil, passed: true), Stop(seq: 2, name: "Uppsala C", eta: eta, passed: false)]
            // The operators may not have been loaded when the replay began.
            if brandColor == nil { brandColor = app.operatorsById["sj"]?.brandColor }
            try? await Task.sleep(for: .seconds(5))
        }
    }
    #endif
}
