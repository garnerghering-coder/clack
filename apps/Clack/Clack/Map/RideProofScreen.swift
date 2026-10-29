//
//  RideProofScreen.swift
//  Clack
//

#if DEBUG
import ClackCore
import MapKit
import RealityKit
import SwiftUI

/// The proof behind the Ride view (BUILDOUT F3): Apple's 3D map (`MKMapView`, realistic elevation) with a RealityKit
/// train drawn over it, the two cameras kept in step every frame, following a replayed run along a real track
/// (`GET /api/live/segment`). It answers two questions with numbers: how far the drawn train sits from where the map
/// would put it (pixels), and how long frames take. Debug only: `-open rideproof`. Nothing here ships.
struct RideProofScreen: View {
    @Environment(AppModel.self) private var app
    @State private var track: [LatLon] = []
    @State private var status = "Loading the track…"
    @State private var stats = RideProofStats()
    @State private var template = TrainKit.Template.multipleUnit
    @State private var cars = 4
    @State private var pitch = 65.0
    @State private var distance = 320.0
    @State private var paused = false

    var body: some View {
        ZStack(alignment: .bottom) {
            if track.count >= 2 {
                RideProofView(track: track, template: template, cars: cars, pitch: pitch, distance: distance, paused: paused, brandColor: app.operatorsById["sj"]?.brandColor, stats: $stats)
                    .ignoresSafeArea()
            } else {
                Text(status).padding()
            }
            panel
        }
        .task { await load() }
        .navigationTitle("Ride proof")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var panel: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(String(format: "frame %.1f ms (p90 %.1f) · sync error %.1f px (max %.1f) · %d frames", stats.frameMsMedian, stats.frameMsP90, stats.syncErrorPx, stats.syncErrorMaxPx, stats.frames))
                .font(.caption.monospacedDigit())
            Picker("Design", selection: $template) {
                ForEach(TrainKit.Template.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            HStack {
                Stepper("Cars \(cars)", value: $cars, in: 1...12)
                Toggle("Pause", isOn: $paused).labelsHidden()
            }
            HStack {
                Text("Pitch \(Int(pitch))°").font(.caption)
                Slider(value: $pitch, in: 30...75)
                Text("Dist \(Int(distance)) m").font(.caption)
                Slider(value: $distance, in: 120...900)
            }
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding()
    }

    /// Stockholm C → Uppsala C, a straight-ish 66 km run with a few curves; any station pair works.
    private func load() async {
        do {
            let seg: SegmentAnswer = try await app.client.get(["live", "segment"], query: ["from": "740000001", "to": "740000005"])
            track = Polyline.decode(seg.polyline)
            if track.count < 2 { status = "Empty track" }
        } catch {
            status = "Track failed: \(error.localizedDescription)"
        }
    }

    private nonisolated struct SegmentAnswer: Decodable, Sendable { let polyline: String; let lengthM: Double }
}

struct RideProofStats {
    var frameMsMedian = 0.0
    var frameMsP90 = 0.0
    var syncErrorPx = 0.0
    var syncErrorMaxPx = 0.0
    var frames = 0
}

/// The map and the RealityKit layer, one UIView holding both, with a display link that moves the train, sets both
/// cameras and measures.
private struct RideProofView: UIViewRepresentable {
    let track: [LatLon]
    let template: TrainKit.Template
    let cars: Int
    let pitch: Double
    let distance: Double
    let paused: Bool
    let brandColor: String?
    @Binding var stats: RideProofStats

    func makeUIView(context: Context) -> RideProofUIView {
        let v = RideProofUIView()
        v.onStats = { s in Task { @MainActor in stats = s } }
        return v
    }

    func updateUIView(_ v: RideProofUIView, context: Context) {
        v.configure(track: track, template: template, cars: cars, pitch: pitch, distance: distance, paused: paused, brandColor: brandColor)
    }
}

final class RideProofUIView: UIView {
    private let map = MKMapView()
    private let arView = ARView(frame: .zero, cameraMode: .nonAR, automaticallyConfigureSession: false)
    private let cameraEntity = PerspectiveCamera()
    private var trainEntity: Entity?
    private var link: CADisplayLink?
    private var track: [LatLon] = []
    private var cum: [Double] = []
    private var headM = 300.0
    private var lastTick: CFTimeInterval = 0
    private var frameTimes: [Double] = []
    private var errors: [Double] = []
    private var frames = 0
    private var template = TrainKit.Template.multipleUnit
    private var cars = 4
    private var pitch = 65.0
    private var distance = 320.0
    private var paused = false
    private var brandColor: String?
    private var needsTrain = true
    var onStats: ((RideProofStats) -> Void)?

    /// Metres per second of the replay (120 km/h).
    private let speed = 33.3

    override init(frame: CGRect) {
        super.init(frame: frame)
        map.preferredConfiguration = MKStandardMapConfiguration(elevationStyle: .realistic, emphasisStyle: .default)
        map.isPitchEnabled = true
        map.isUserInteractionEnabled = false
        map.showsCompass = false
        addSubview(map)
        arView.environment.background = .color(.clear)
        arView.isUserInteractionEnabled = false
        let anchor = AnchorEntity(world: .zero)
        anchor.addChild(cameraEntity)
        arView.scene.addAnchor(anchor)
        addSubview(arView)
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

    func configure(track: [LatLon], template: TrainKit.Template, cars: Int, pitch: Double, distance: Double, paused: Bool, brandColor: String?) {
        if track != self.track {
            self.track = track
            cum = TrainKit.cumulative(track)
            headM = 300
            if let first = track.first { map.setCamera(MKMapCamera(lookingAtCenter: CLLocationCoordinate2D(latitude: first.lat, longitude: first.lon), fromDistance: distance, pitch: pitch, heading: 0), animated: false) }
        }
        if template != self.template || cars != self.cars || brandColor != self.brandColor { needsTrain = true }
        self.template = template
        self.cars = cars
        self.pitch = pitch
        self.distance = distance
        self.paused = paused
        self.brandColor = brandColor
    }

    @objc private func tick(_ link: CADisplayLink) {
        guard track.count >= 2 else { return }
        let start = CACurrentMediaTime()
        if lastTick > 0, !paused { headM += (link.timestamp - lastTick) * speed }
        lastTick = link.timestamp
        let total = cum.last ?? 0
        if headM > total - 10 { headM = 300 }
        let carLength = TrainKit.carLength(template)
        let poses = TrainKit.carPoses(track: track, headM: headM, count: cars, carLength: carLength)
        guard let front = poses.first else { return }
        // The camera looks at the middle of the train, along the front car's heading.
        let mid = TrainKit.carPoses(track: track, headM: headM - TrainKit.trainLength(count: cars, carLength: carLength) / 2 + carLength / 2, count: 1, carLength: 1).first?.center ?? front.center
        let wanted = front.headingDeg
        let center = CLLocationCoordinate2D(latitude: mid.lat, longitude: mid.lon)
        map.setCamera(MKMapCamera(lookingAtCenter: center, fromDistance: distance, pitch: pitch, heading: wanted), animated: false)
        let heading = map.camera.heading

        // The RealityKit camera: the same place relative to the look-at point. MapKit's camera sits `distance` from
        // the centre along its line of sight; with pitch p from the vertical it is distance·cos p up and
        // distance·sin p behind (against the heading), looking at the centre.
        // MapKit clamps pitch (and may adjust the rest) to what the map allows: use what it actually set.
        let actual = map.camera
        let actualPitch = Double(actual.pitch)
        let actualDistance = actualPitch < 89 ? actual.altitude / cos(actualPitch * .pi / 180) : distance
        let p = Float(actualPitch * .pi / 180)
        let d = Float(actualDistance)
        cameraEntity.position = [0, d * cos(p), d * sin(p)]
        cameraEntity.look(at: .zero, from: cameraEntity.position, relativeTo: nil)
        // Field of view: matched so a metre of ground at the centre covers the same pixels as on the map. MapKit's
        // own FOV isn't published, so it is read off the map each frame from two projected points.
        let probeA = map.convert(center, toPointTo: map)
        let probeMetres = 40.0
        let probeCoord = offset(center, metresNorthOfHeading: probeMetres, heading: heading)
        let probeB = map.convert(probeCoord, toPointTo: map)
        let px = Double(hypot(probeB.x - probeA.x, probeB.y - probeA.y))
        if px > 0.5, bounds.height > 0 {
            // A forward ground metre at the centre projects to L·cos(p)·f/d pixels, f = (H/2)/tan(fov/2).
            let f = px * actualDistance / (probeMetres * cos(actualPitch * .pi / 180))
            let fov = 2 * atan(Double(bounds.height) / 2 / f) * 180 / .pi
            cameraEntity.camera.fieldOfViewInDegrees = Float(max(10, min(120, fov)))
        }
        // The train, rebuilt only when its make-up changes; moved every frame.
        if needsTrain || trainEntity == nil {
            trainEntity?.removeFromParent()
            let colours = TrainScene.Colours.forOperator(brandColor, dark: traitCollection.userInterfaceStyle == .dark)
            let t = TrainScene.train(template: template, poses: poses, colours: colours, carLength: carLength, origin: mid, viewHeadingDeg: heading)
            let anchor = AnchorEntity(world: .zero)
            anchor.addChild(t)
            arView.scene.addAnchor(anchor)
            trainEntity = t
            needsTrain = false
        } else if let t = trainEntity {
            // Re-place the cars (cheaper than rebuilding: same children, new transforms).
            for (i, pose) in poses.enumerated() where i < t.children.count {
                let (east, north) = TrainScene.metres(from: mid, to: pose.center)
                let viewRad = heading * .pi / 180
                let x = Float(east * cos(viewRad) - north * sin(viewRad))
                let z = Float(-(east * sin(viewRad) + north * cos(viewRad)))
                t.children[i].position = [x, 0, z]
                t.children[i].orientation = simd_quatf(angle: Float((heading - pose.headingDeg) * .pi / 180), axis: [0, 1, 0])
            }
        }
        // Sync error: where the map puts the front car vs where RealityKit projects it.
        let frontMap = map.convert(CLLocationCoordinate2D(latitude: front.center.lat, longitude: front.center.lon), toPointTo: map)
        if let t = trainEntity, let frontCar = t.children.first, let frontAR = arView.project(frontCar.position(relativeTo: nil)) {
            errors.append(Double(hypot(frontAR.x - frontMap.x, frontAR.y - frontMap.y)))
        }
        frameTimes.append((CACurrentMediaTime() - start) * 1000)
        frames += 1
        if frames % 30 == 0 {
            let ft = frameTimes.sorted(), er = errors.sorted()
            onStats?(RideProofStats(
                frameMsMedian: ft[ft.count / 2], frameMsP90: ft[min(ft.count - 1, Int(Double(ft.count) * 0.9))],
                syncErrorPx: er.isEmpty ? 0 : er[er.count / 2], syncErrorMaxPx: er.last ?? 0, frames: frames
            ))
            if frameTimes.count > 600 { frameTimes.removeFirst(300) }
            if errors.count > 600 { errors.removeFirst(300) }
        }
    }

    private func offset(_ c: CLLocationCoordinate2D, metresNorthOfHeading m: Double, heading: Double) -> CLLocationCoordinate2D {
        let h = heading * .pi / 180
        let dn = m * cos(h), de = m * sin(h)
        return CLLocationCoordinate2D(latitude: c.latitude + dn / 111_320, longitude: c.longitude + de / (111_320 * cos(c.latitude * .pi / 180)))
    }
}
#endif
