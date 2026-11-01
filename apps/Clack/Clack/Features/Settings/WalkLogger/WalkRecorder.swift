//
//  WalkRecorder.swift
//  Clack
//

import ARKit
import ClackCore
import CoreLocation
import CoreMotion
import SwiftUI

/// Records a station walk (owner test tool): every sensor the phone offers, timestamped, into a `WalkLog`.
/// Location, compass, barometer (relative and absolute), device motion at 50 Hz, pedometer, motion activity, and in AR
/// mode the camera's pose (no images); in LiDAR mode (phones with LiDAR) also the 3D mesh of the surroundings. The screen stays on while recording: iOS pauses motion updates for apps in the
/// background, so the walk is only complete while Clack is open.
@MainActor
@Observable
final class WalkRecorder: NSObject {
    /// One for the app, so a walk keeps going when you leave the screen.
    static let shared = WalkRecorder(store: .shared)

    private(set) var log: WalkLog?
    private(set) var currentRouteIndex: Int?
    private(set) var arOn = false
    private(set) var lidarOn = false
    /// Triangles in the LiDAR mesh so far (while LiDAR mode is on).
    private(set) var lidarFaces = 0
    /// Whether this phone can build a LiDAR mesh (iPhone Pro models, iPad Pro).
    static let lidarSupported = ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh)
    private(set) var lastLocation: CLLocation?
    private(set) var lastRelAlt: Double?
    private(set) var lastSteps = 0
    var problem: String?

    private let store: WalkStore
    private let location = CLLocationManager()
    private let altimeter = CMAltimeter()
    private let motion = CMMotionManager()
    private let pedometer = CMPedometer()
    private let activity = CMMotionActivityManager()
    private var arSession: ARSession?
    /// The mesh pieces ARKit keeps refining, latest version of each; turned into one snapshot when LiDAR mode ends.
    private var meshAnchors: [UUID: ARMeshAnchor] = [:]
    private var lastARSample = 0.0
    private var saveTimer: Timer?
    /// Device-motion timestamps are seconds since boot; this turns them into seconds since 1970.
    private let bootOffset = Date().timeIntervalSince1970 - ProcessInfo.processInfo.systemUptime

    init(store: WalkStore) {
        self.store = store
        super.init()
        location.delegate = self
    }

    var isRecording: Bool { log != nil }
    var currentRoute: WalkLog.Route? { currentRouteIndex.flatMap { log?.routes[$0] } }

    private var now: Double { Date().timeIntervalSince1970 }

    // MARK: - Walk

    func start(title: String) {
        guard log == nil else { return }
        let device = WalkLog.Device(model: Self.deviceModel, system: "iOS \(UIDevice.current.systemVersion)", appBuild: Self.appBuild)
        log = WalkLog(title: title.isEmpty ? "Walk \(Date().formatted(date: .abbreviated, time: .shortened))" : title, startedAt: now, device: device)
        UIApplication.shared.isIdleTimerDisabled = true
        startSensors()
        saveTimer = Timer.scheduledTimer(withTimeInterval: 20, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.save() }
        }
    }

    /// Ends the walk, saves it and hands it to the store to upload. Returns its id.
    @discardableResult
    func stop() -> String? {
        guard var final = log else { return nil }
        if let i = currentRouteIndex, final.routes[i].endedAt == nil { final.routes[i].endedAt = now }
        final.endedAt = now
        log = final
        stopSensors()
        saveTimer?.invalidate()
        saveTimer = nil
        UIApplication.shared.isIdleTimerDisabled = false
        save()
        store.upload(final.id)
        let id = final.id
        log = nil
        currentRouteIndex = nil
        return id
    }

    private func save() {
        guard let log else { return }
        store.save(log)
    }

    // MARK: - Routes and marks

    func startRoute(name: String) {
        guard log != nil else { return }
        endRoute(note: nil)
        let route = WalkLog.Route(name: name.isEmpty ? "Route \((log?.routes.count ?? 0) + 1)" : name, startedAt: now)
        log?.routes.append(route)
        currentRouteIndex = (log?.routes.count ?? 1) - 1
    }

    func endRoute(note: String?) {
        guard let i = currentRouteIndex else { return }
        log?.routes[i].endedAt = now
        if let note, !note.isEmpty { log?.routes[i].note = note }
        currentRouteIndex = nil
        save()
    }

    /// A landmark, with where the phone thinks it is right now (the ground truth to compare against later).
    func mark(_ label: String) {
        guard log != nil else { return }
        if currentRouteIndex == nil { startRoute(name: "") }
        guard let i = currentRouteIndex else { return }
        let loc = lastLocation
        let m = WalkLog.Mark(t: now, label: label.isEmpty ? "Mark \((log?.routes[i].marks.count ?? 0) + 1)" : label,
                             lat: loc?.coordinate.latitude, lon: loc?.coordinate.longitude, hAcc: loc?.horizontalAccuracy, relAlt: lastRelAlt)
        log?.routes[i].marks.append(m)
    }

    func toggleChecklist(_ item: String) {
        guard var list = log?.checklist else { return }
        if let i = list.firstIndex(of: item) { list.remove(at: i) } else { list.append(item) }
        log?.checklist = list
    }

    // MARK: - AR mode

    func setAR(_ on: Bool) {
        guard log != nil, on != arOn else { return }
        if on {
            guard ARWorldTrackingConfiguration.isSupported else { problem = "AR world tracking isn't supported on this phone."; return }
            let session = ARSession()
            session.delegate = self
            session.delegateQueue = .main
            session.run(arConfiguration(lidar: false))
            arSession = session
            log?.events.append(.init(t: now, kind: "ar", detail: "on"))
        } else {
            if lidarOn { setLiDAR(false) }
            arSession?.pause()
            arSession = nil
            log?.events.append(.init(t: now, kind: "ar", detail: "off"))
        }
        arOn = on
    }

    /// LiDAR mode: AR mode plus the mesh ARKit builds from the LiDAR scanner. Turning it off keeps the mesh so far as
    /// one snapshot in the walk (`meshes`); turning it on again starts a new one.
    func setLiDAR(_ on: Bool) {
        guard log != nil, on != lidarOn else { return }
        if on {
            guard Self.lidarSupported else { problem = "This phone has no LiDAR scanner."; return }
            if !arOn { setAR(true) }
            guard let session = arSession else { return }
            meshAnchors = [:]
            lidarFaces = 0
            // Same session, more work: the tracking (and the poses' frame) carries on.
            session.run(arConfiguration(lidar: true))
            lidarOn = true
            log?.events.append(.init(t: now, kind: "lidar", detail: "on"))
        } else {
            lidarOn = false
            arSession?.run(arConfiguration(lidar: false))
            let mesh = Self.snapshot(Array(meshAnchors.values), t: now)
            meshAnchors = [:]
            if mesh.faceCount > 0 { log?.meshes = (log?.meshes ?? []) + [mesh] }
            log?.events.append(.init(t: now, kind: "lidar", detail: "off: \(mesh.vertexCount) vertices, \(mesh.faceCount) triangles"))
            if let log { store.save(log) }
        }
    }

    private func arConfiguration(lidar: Bool) -> ARWorldTrackingConfiguration {
        let config = ARWorldTrackingConfiguration()
        config.worldAlignment = .gravityAndHeading
        if lidar {
            config.sceneReconstruction = ARWorldTrackingConfiguration.supportsSceneReconstruction(.meshWithClassification) ? .meshWithClassification : .mesh
        }
        return config
    }

    /// The mesh pieces as one mesh in the session's frame (each piece's vertices moved by its transform).
    static func snapshot(_ anchors: [ARMeshAnchor], t: Double) -> WalkLog.ARMesh {
        var vertices = Data(), faces = Data(), classes = Data()
        var vertexCount = 0, faceCount = 0
        var classified = false
        for anchor in anchors {
            let g = anchor.geometry
            let base = UInt32(vertexCount)
            let v = g.vertices
            let vp = v.buffer.contents()
            for i in 0..<v.count {
                let o = v.offset + v.stride * i
                let local = SIMD4<Float>(vp.loadUnaligned(fromByteOffset: o, as: Float.self), vp.loadUnaligned(fromByteOffset: o + 4, as: Float.self), vp.loadUnaligned(fromByteOffset: o + 8, as: Float.self), 1)
                let w = anchor.transform * local
                for c in [w.x, w.y, w.z] { withUnsafeBytes(of: c.bitPattern.littleEndian) { vertices.append(contentsOf: $0) } }
            }
            let f = g.faces
            let fp = f.buffer.contents()
            for i in 0..<(f.count * f.indexCountPerPrimitive) {
                let index: UInt32 = f.bytesPerIndex == 2 ? UInt32(fp.loadUnaligned(fromByteOffset: i * 2, as: UInt16.self)) : fp.loadUnaligned(fromByteOffset: i * 4, as: UInt32.self)
                withUnsafeBytes(of: (base + index).littleEndian) { faces.append(contentsOf: $0) }
            }
            if let c = g.classification {
                classified = true
                let cp = c.buffer.contents()
                for i in 0..<c.count { classes.append(cp.loadUnaligned(fromByteOffset: c.offset + c.stride * i, as: UInt8.self)) }
            } else {
                classes.append(contentsOf: [UInt8](repeating: 0, count: f.count))
            }
            vertexCount += v.count
            faceCount += f.count
        }
        return WalkLog.ARMesh(t: t, vertexCount: vertexCount, faceCount: faceCount, vertices: vertices, faces: faces, classes: classified ? classes : nil)
    }

    // MARK: - Sensors

    private func startSensors() {
        location.desiredAccuracy = kCLLocationAccuracyBest
        location.distanceFilter = kCLDistanceFilterNone
        location.activityType = .otherNavigation
        location.headingFilter = kCLHeadingFilterNone
        if location.authorizationStatus == .notDetermined { location.requestWhenInUseAuthorization() }
        location.startUpdatingLocation()
        if CLLocationManager.headingAvailable() { location.startUpdatingHeading() }

        if CMAltimeter.isRelativeAltitudeAvailable() {
            altimeter.startRelativeAltitudeUpdates(to: .main) { [weak self] data, _ in
                guard let data else { return }
                let rel = data.relativeAltitude.doubleValue, kPa = data.pressure.doubleValue
                MainActor.assumeIsolated {
                    guard let self else { return }
                    self.lastRelAlt = rel
                    self.log?.pressure.append(.init(t: self.now, relAlt: rel, kPa: kPa))
                }
            }
        }
        if CMAltimeter.isAbsoluteAltitudeAvailable() {
            altimeter.startAbsoluteAltitudeUpdates(to: .main) { [weak self] data, _ in
                guard let data else { return }
                let s = WalkLog.AbsoluteAltitude(t: Date().timeIntervalSince1970, alt: data.altitude, accuracy: data.accuracy, precision: data.precision)
                MainActor.assumeIsolated { self?.log?.absoluteAltitude.append(s) }
            }
        }
        if motion.isDeviceMotionAvailable {
            motion.deviceMotionUpdateInterval = 1.0 / 50
            let frame: CMAttitudeReferenceFrame = CMMotionManager.availableAttitudeReferenceFrames().contains(.xMagneticNorthZVertical) ? .xMagneticNorthZVertical : .xArbitraryZVertical
            motion.startDeviceMotionUpdates(using: frame, to: .main) { [weak self] m, _ in
                guard let m else { return }
                let q = m.attitude.quaternion, r = m.rotationRate, a = m.userAcceleration, g = m.gravity, f = m.magneticField
                MainActor.assumeIsolated {
                    guard let self else { return }
                    self.log?.motion.append(.init(
                        t: self.bootOffset + m.timestamp, q: [q.x, q.y, q.z, q.w], rot: [r.x, r.y, r.z], acc: [a.x, a.y, a.z],
                        grav: [g.x, g.y, g.z], mag: [f.field.x, f.field.y, f.field.z], magAcc: Int(f.accuracy.rawValue)))
                }
            }
        }
        if CMPedometer.isStepCountingAvailable() {
            let from = Date()
            pedometer.startUpdates(from: from) { [weak self] data, _ in
                guard let data else { return }
                let s = WalkLog.Steps(
                    t: data.endDate.timeIntervalSince1970, steps: data.numberOfSteps.intValue, distance: data.distance?.doubleValue,
                    cadence: data.currentCadence?.doubleValue, pace: data.currentPace?.doubleValue,
                    floorsUp: data.floorsAscended?.intValue, floorsDown: data.floorsDescended?.intValue)
                Task { @MainActor in
                    self?.lastSteps = s.steps
                    self?.log?.steps.append(s)
                }
            }
            if CMPedometer.isPedometerEventTrackingAvailable() {
                pedometer.startEventUpdates { [weak self] event, _ in
                    guard let event else { return }
                    let e = WalkLog.StepEvent(t: event.date.timeIntervalSince1970, kind: event.type == .pause ? "pause" : "resume")
                    Task { @MainActor in self?.log?.stepEvents.append(e) }
                }
            }
        }
        if CMMotionActivityManager.isActivityAvailable() {
            activity.startActivityUpdates(to: .main) { [weak self] a in
                guard let a else { return }
                let s = WalkLog.Activity(t: a.startDate.timeIntervalSince1970, stationary: a.stationary, walking: a.walking, running: a.running,
                                         automotive: a.automotive, unknown: a.unknown, confidence: a.confidence.rawValue)
                MainActor.assumeIsolated { self?.log?.activity.append(s) }
            }
        }
    }

    private func stopSensors() {
        location.stopUpdatingLocation()
        location.stopUpdatingHeading()
        altimeter.stopRelativeAltitudeUpdates()
        altimeter.stopAbsoluteAltitudeUpdates()
        motion.stopDeviceMotionUpdates()
        pedometer.stopUpdates()
        pedometer.stopEventUpdates()
        activity.stopActivityUpdates()
        setAR(false)
    }

    /// The app went to the background (or came back): the sensors that pause there leave a gap, recorded as such.
    func noteScenePhase(_ phase: ScenePhase) {
        guard log != nil else { return }
        log?.events.append(.init(t: now, kind: "scene", detail: "\(phase)"))
    }

    // MARK: - Device

    static var deviceModel: String {
        var info = utsname()
        uname(&info)
        return withUnsafeBytes(of: &info.machine) { String(decoding: $0.prefix { $0 != 0 }, as: UTF8.self) }
    }

    static var appBuild: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        return "\(v) (\(b))"
    }
}

extension WalkRecorder: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let samples = locations.map { l in
            WalkLog.Location(
                t: l.timestamp.timeIntervalSince1970, lat: l.coordinate.latitude, lon: l.coordinate.longitude, alt: l.altitude,
                hAcc: l.horizontalAccuracy, vAcc: l.verticalAccuracy, speed: l.speed, speedAcc: l.speedAccuracy,
                course: l.course, courseAcc: l.courseAccuracy, floor: l.floor?.level,
                simulated: l.sourceInformation?.isSimulatedBySoftware ?? false, accessory: l.sourceInformation?.isProducedByAccessory ?? false)
        }
        let last = locations.last
        MainActor.assumeIsolated {
            self.lastLocation = last
            self.log?.location.append(contentsOf: samples)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateHeading h: CLHeading) {
        let s = WalkLog.Heading(t: h.timestamp.timeIntervalSince1970, magnetic: h.magneticHeading, trueHeading: h.trueHeading, accuracy: h.headingAccuracy)
        MainActor.assumeIsolated { self.log?.heading.append(s) }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: any Error) {
        let text = error.localizedDescription
        MainActor.assumeIsolated { self.log?.events.append(.init(t: Date().timeIntervalSince1970, kind: "locationError", detail: text)) }
    }
}

extension WalkRecorder: ARSessionDelegate {
    nonisolated func session(_ session: ARSession, didUpdate frame: ARFrame) {
        let t = Date().timeIntervalSince1970
        let m = frame.camera.transform
        let q = simd_quatf(m)
        let tracking: String = switch frame.camera.trackingState {
        case .normal: "normal"
        case .notAvailable: "notAvailable"
        case .limited(let reason): "limited:\(reason)"
        }
        let mapping: String = switch frame.worldMappingStatus {
        case .notAvailable: "notAvailable"
        case .limited: "limited"
        case .extending: "extending"
        case .mapped: "mapped"
        @unknown default: "unknown"
        }
        let pose = WalkLog.ARPose(t: t, p: [Double(m.columns.3.x), Double(m.columns.3.y), Double(m.columns.3.z)],
                                  q: [Double(q.imag.x), Double(q.imag.y), Double(q.imag.z), Double(q.real)], tracking: tracking, mapping: mapping)
        MainActor.assumeIsolated {
            // 30 a second is plenty for a walk.
            guard t - self.lastARSample >= 1.0 / 30 else { return }
            self.lastARSample = t
            self.log?.ar.append(pose)
        }
    }

    nonisolated func session(_ session: ARSession, didAdd anchors: [ARAnchor]) { keepMeshes(anchors) }
    nonisolated func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) { keepMeshes(anchors) }

    /// The latest version of each mesh piece (the delegate runs on the main queue).
    nonisolated private func keepMeshes(_ anchors: [ARAnchor]) {
        let meshes = anchors.compactMap { $0 as? ARMeshAnchor }
        guard !meshes.isEmpty else { return }
        MainActor.assumeIsolated {
            guard self.lidarOn else { return }
            for m in meshes { self.meshAnchors[m.identifier] = m }
            self.lidarFaces = self.meshAnchors.values.reduce(0) { $0 + $1.geometry.faces.count }
        }
    }

    nonisolated func session(_ session: ARSession, didFailWithError error: any Error) {
        let text = error.localizedDescription
        MainActor.assumeIsolated {
            self.log?.events.append(.init(t: Date().timeIntervalSince1970, kind: "arError", detail: text))
            self.problem = "AR stopped: \(text)"
        }
    }
}
