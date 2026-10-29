//
//  RideMapView.swift
//  Clack
//

import ClackCore
import ClackDesign
import MapKit
import RealityKit
import SwiftUI

/// The Ride view's map (BUILDOUT O3, on the F3 proof): Apple's 3D map (`MKMapView`, realistic elevation) following
/// the train, with the train drawn by RealityKit in a view laid exactly over it, the two cameras kept in step every
/// frame. The train moves on between position reports at its last speed and is eased to each new report rather than
/// jumped. The route is a line on the map in the operator's colour. The train sits over the map, never behind a
/// building: that is a MapKit limit, said in the panel.
struct RideMapView: UIViewRepresentable {
    let track: RideLogic.Track
    let template: TrainKit.Template
    let cars: Int
    let brandColor: String?
    let camera: RideLogic.Camera
    /// The last report: metres along the track, the time it was for (epoch ms), the speed then, and the metres the
    /// train may not pass before the next report (its next stop, or the end).
    let report: RideReport?
    let dark: Bool
    /// Room the panel takes, so Apple's attribution and the camera's look-at point stay clear of it.
    var insets: UIEdgeInsets = .zero
    /// A pinch: the scale so far and whether the gesture ended.
    var onPinch: (CGFloat, Bool) -> Void = { _, _ in }

    func makeUIView(context: Context) -> RideMapUIView {
        let v = RideMapUIView()
        v.onPinch = onPinch
        return v
    }

    func updateUIView(_ v: RideMapUIView, context: Context) {
        v.onPinch = onPinch
        v.configure(track: track, template: template, cars: cars, brandColor: brandColor, camera: camera, dark: dark)
        v.insets = insets
        if let report { v.setReport(report) }
    }
}

/// One position report, for the map to move the train from.
struct RideReport: Equatable {
    var metres: Double
    var at: Double
    var speedKmh: Double?
    var limitM: Double
}

final class RideMapUIView: UIView, MKMapViewDelegate {
    private let map = MKMapView()
    private let arView = ARView(frame: .zero, cameraMode: .nonAR, automaticallyConfigureSession: false)
    private let cameraEntity = PerspectiveCamera()
    private var trainEntity: Entity?
    private var link: CADisplayLink?
    private var track = RideLogic.Track(points: [])
    private var routeOverlay: MKPolyline?
    private weak var routeRenderer: MKPolylineRenderer?
    private var routeColor = UIColor.systemBlue
    private var headM = 0.0
    private var report: RideReport?
    private var lastTick: CFTimeInterval = 0
    private var template = TrainKit.Template.multipleUnit
    private var cars = 4
    private var brandColor: String?
    private var camera = RideLogic.camera(.behind)
    private var dark = false
    private var needsTrain = true
    var onPinch: (CGFloat, Bool) -> Void = { _, _ in }
    /// MapKit keeps its attribution inside the layout margins: the panel's room goes there.
    var insets = UIEdgeInsets.zero {
        didSet { if insets != oldValue { map.directionalLayoutMargins = NSDirectionalEdgeInsets(top: insets.top, leading: insets.left, bottom: insets.bottom, trailing: insets.right) } }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        map.preferredConfiguration = MKStandardMapConfiguration(elevationStyle: .realistic, emphasisStyle: .default)
        map.isPitchEnabled = true
        map.isUserInteractionEnabled = false
        map.showsCompass = false
        map.preservesSuperviewLayoutMargins = false
        map.insetsLayoutMarginsFromSafeArea = false
        map.delegate = self
        addSubview(map)
        arView.environment.background = .color(.clear)
        arView.isUserInteractionEnabled = false
        let anchor = AnchorEntity(world: .zero)
        anchor.addChild(cameraEntity)
        arView.scene.addAnchor(anchor)
        addSubview(arView)
        let pinch = UIPinchGestureRecognizer(target: self, action: #selector(pinched(_:)))
        addGestureRecognizer(pinch)
        link = CADisplayLink(target: self, selector: #selector(tick))
        link?.add(to: .main, forMode: .common)
    }

    required init?(coder: NSCoder) { fatalError() }

    deinit { link?.invalidate() }

    override func layoutSubviews() {
        super.layoutSubviews()
        map.frame = bounds
        arView.frame = bounds
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        // No work while off screen.
        link?.isPaused = window == nil
    }

    @objc private func pinched(_ g: UIPinchGestureRecognizer) {
        onPinch(g.scale, g.state == .ended || g.state == .cancelled)
    }

    func configure(track: RideLogic.Track, template: TrainKit.Template, cars: Int, brandColor: String?, camera: RideLogic.Camera, dark: Bool) {
        if track != self.track {
            self.track = track
            if let old = routeOverlay { map.removeOverlay(old) }
            if track.points.count >= 2 {
                let coords = track.points.map { CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lon) }
                let line = MKPolyline(coordinates: coords, count: coords.count)
                map.addOverlay(line, level: .aboveRoads)
                routeOverlay = line
            }
        }
        if template != self.template || cars != self.cars || brandColor != self.brandColor || dark != self.dark { needsTrain = true }
        self.template = template
        self.cars = cars
        self.brandColor = brandColor
        self.camera = camera
        self.dark = dark
        routeColor = UIColor(operatorColor(brandColor, scheme: dark ? .dark : .light))
        routeRenderer?.strokeColor = routeColor.withAlphaComponent(0.85)
    }

    /// A new report: the train is eased towards it over the next second rather than jumped (unless far off).
    func setReport(_ r: RideReport) {
        let first = report == nil
        report = r
        if first || abs(r.metres - headM) > 2000 { headM = r.metres }
    }

    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        guard let line = overlay as? MKPolyline else { return MKOverlayRenderer(overlay: overlay) }
        let r = MKPolylineRenderer(polyline: line)
        r.strokeColor = routeColor.withAlphaComponent(0.85)
        r.lineWidth = 4
        r.lineCap = .round
        r.lineJoin = .round
        routeRenderer = r
        return r
    }

    @objc private func tick(_ link: CADisplayLink) {
        guard track.points.count >= 2, bounds.width > 0 else { return }
        let dt = lastTick > 0 ? min(0.5, link.timestamp - lastTick) : 0
        lastTick = link.timestamp
        // Where the train should be now: the report moved on at its speed, held at its next stop; the drawn train
        // closes on it over about a second, so a late report slides the train rather than jumping it.
        if let r = report {
            let now = Date.now.timeIntervalSince1970 * 1000
            let want = min(r.limitM, RideLogic.extrapolate(metres: r.metres, reportedAt: r.at, speedKmh: r.speedKmh, now: now, track: track))
            let speed = (r.speedKmh ?? 0) / 3.6
            headM += speed * dt
            headM += (want - headM) * min(1, dt / 1.0)
            headM = max(0, min(track.length, headM))
        }
        let carLength = TrainKit.carLength(template)
        let poses = TrainKit.carPoses(track: track.points, headM: headM, count: cars, carLength: carLength)
        guard let front = poses.first else { return }
        let trainLength = TrainKit.trainLength(count: cars, carLength: carLength)
        // Looked at: the middle of the train, or a point down the line for the driver's eye.
        let lookM = camera.lookAheadM > 0 ? headM + camera.lookAheadM : headM - trainLength / 2 + carLength / 2
        let look = track.point(at: lookM) ?? front.center
        let heading = (front.headingDeg + camera.headingOffset).truncatingRemainder(dividingBy: 360)
        let center = CLLocationCoordinate2D(latitude: look.lat, longitude: look.lon)
        map.setCamera(MKMapCamera(lookingAtCenter: center, fromDistance: camera.distance, pitch: camera.pitch, heading: heading), animated: false)

        // The RealityKit camera in the same place as MapKit's (which may have clamped the pitch): distance·cos p up,
        // distance·sin p behind, looking at the centre; the field of view read off the map from two projected points.
        let actual = map.camera
        let actualPitch = Double(actual.pitch)
        let actualDistance = actualPitch < 89 ? actual.altitude / cos(actualPitch * .pi / 180) : camera.distance
        let actualHeading = actual.heading
        let p = Float(actualPitch * .pi / 180)
        let d = Float(actualDistance)
        cameraEntity.position = [0, d * cos(p), d * sin(p)]
        cameraEntity.look(at: .zero, from: cameraEntity.position, relativeTo: nil)
        let probeA = map.convert(center, toPointTo: map)
        let probeMetres = 40.0
        let probeB = map.convert(offset(center, metresAlong: probeMetres, heading: actualHeading), toPointTo: map)
        let px = Double(hypot(probeB.x - probeA.x, probeB.y - probeA.y))
        if px > 0.5, bounds.height > 0 {
            let f = px * actualDistance / (probeMetres * cos(actualPitch * .pi / 180))
            let fov = 2 * atan(Double(bounds.height) / 2 / f) * 180 / .pi
            cameraEntity.camera.fieldOfViewInDegrees = Float(max(10, min(120, fov)))
        }
        // The train: rebuilt when its make-up changes, else its cars re-placed.
        if needsTrain || trainEntity == nil {
            trainEntity?.removeFromParent()
            let colours = TrainScene.Colours.forOperator(brandColor, dark: dark)
            let t = TrainScene.train(template: template, poses: poses, colours: colours, carLength: carLength, origin: look, viewHeadingDeg: actualHeading)
            let anchor = AnchorEntity(world: .zero)
            anchor.addChild(t)
            arView.scene.addAnchor(anchor)
            trainEntity = t
            needsTrain = false
        } else if let t = trainEntity {
            let viewRad = actualHeading * .pi / 180
            for (i, pose) in poses.enumerated() where i < t.children.count {
                let (east, north) = TrainScene.metres(from: look, to: pose.center)
                t.children[i].position = [Float(east * cos(viewRad) - north * sin(viewRad)), 0, Float(-(east * sin(viewRad) + north * cos(viewRad)))]
                t.children[i].orientation = simd_quatf(angle: Float((actualHeading - pose.headingDeg) * .pi / 180), axis: [0, 1, 0])
            }
        }
    }

    private func offset(_ c: CLLocationCoordinate2D, metresAlong m: Double, heading: Double) -> CLLocationCoordinate2D {
        let h = heading * .pi / 180
        return CLLocationCoordinate2D(latitude: c.latitude + m * cos(h) / 111_320, longitude: c.longitude + m * sin(h) / (111_320 * cos(c.latitude * .pi / 180)))
    }
}
