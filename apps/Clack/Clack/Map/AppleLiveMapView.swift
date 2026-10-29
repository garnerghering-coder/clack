//
//  AppleLiveMapView.swift
//  Clack
//

import ClackCore
import ClackDesign
import MapKit
import SwiftUI
import UIKit

/// What a live map must do for Explore, so the screen's model can drive MapLibre (the default) or Apple Maps (the
/// test engine, Settings → Map engine) through the same `LiveMapController`.
@MainActor
protocol LiveMapSurface: AnyObject {
    var zoom: Double { get }
    var height: CGFloat { get }
    func setTrains(_ points: [TrainPoint])
    func moveTrains(_ positions: [String: LatLon])
    func setSelected(_ id: String?)
    func setRoute(done: [LatLon], ahead: [LatLon])
    func clearRoute()
    func setRouteColor(_ hex: String)
    func setCorridor(lines: [[LatLon]], trainIds: [String])
    func clearCorridor()
    func ease(to c: CLLocationCoordinate2D, minZoom: Double, offset: CGFloat)
    func fit(_ points: [LatLon], padding: UIEdgeInsets)
    func contains(_ lat: Double, _ lon: Double) -> Bool
    func applyDisplay(_ display: MapDisplay)
    func showUserDot(_ on: Bool)
    func centreOnUser()
}

/// Explore on Apple Maps (BUILDOUT O3, behind a setting): `MKMapView` with realistic elevation, trains as one overlay
/// of dots when zoomed out and as annotation views (the same marker pictures as the Clack map) from zoom 7, the
/// selected train's route and a corridor as polylines, your own dot from MapKit. Stations are Apple's own and can't
/// be tapped for a board here (said in the log). A display link measures the frame interval for the readout.
struct AppleLiveMapView: UIViewRepresentable {
    let controller: LiveMapController
    let base: URL
    let dark: Bool

    func makeCoordinator() -> AppleLiveMapSurface { AppleLiveMapSurface(controller: controller) }

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView()
        // Flat and muted: the trains and the rail lines are the point, and the phone stays cool (owner, 2026-10-29).
        map.preferredConfiguration = MKStandardMapConfiguration(elevationStyle: .flat, emphasisStyle: .muted)
        map.showsCompass = false
        map.showsScale = false
        map.isPitchEnabled = false
        map.isRotateEnabled = true
        map.pointOfInterestFilter = .excludingAll
        map.delegate = context.coordinator
        map.register(TrainAnnotationView.self, forAnnotationViewWithReuseIdentifier: TrainAnnotationView.reuseId)
        context.coordinator.map = map
        context.coordinator.dark = dark
        controller.surface = context.coordinator
        controller.rebuilt()
        // The same opening view as the Clack map: Bergen to the Finnish east border, Gedser to Nordkapp.
        map.setRegion(MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: 63, longitude: 17), span: MKCoordinateSpan(latitudeDelta: 18, longitudeDelta: 30)), animated: false)
        map.addOverlay(context.coordinator.farOverlay, level: .aboveLabels)
        context.coordinator.startMeasuring()
        context.coordinator.loadRailNetwork(base)
        return map
    }

    func updateUIView(_ map: MKMapView, context: Context) {
        context.coordinator.dark = dark
    }

    static func dismantleUIView(_ map: MKMapView, coordinator: AppleLiveMapSurface) {
        coordinator.stopMeasuring()
        if coordinator.controller.surface === coordinator { coordinator.controller.surface = nil }
    }
}

/// A station from the rail network, drawn like Apple's transit view: a small dot with its name from zoom 9.
final class StationAnnotation: NSObject, MKAnnotation {
    let coordinate: CLLocationCoordinate2D
    let id: String
    let name: String
    init(id: String, name: String, coordinate: CLLocationCoordinate2D) {
        self.id = id
        self.name = name
        self.coordinate = coordinate
    }
}

final class StationAnnotationView: MKAnnotationView {
    static let reuseId = "station"
    private let dot = UIView()
    private let label = UILabel()

    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        frame = CGRect(x: 0, y: 0, width: 10, height: 10)
        collisionMode = .circle
        displayPriority = .defaultLow
        dot.frame = bounds
        dot.layer.cornerRadius = 5
        dot.layer.borderWidth = 1.5
        addSubview(dot)
        label.font = UIFont.systemFont(ofSize: 11, weight: .semibold)
        label.frame = CGRect(x: 14, y: -3, width: 140, height: 16)
        addSubview(label)
    }

    required init?(coder: NSCoder) { fatalError() }

    func apply(_ a: StationAnnotation, showName: Bool, dark: Bool) {
        dot.backgroundColor = AppleLiveMapSurface.railBlue
        dot.layer.borderColor = (dark ? UIColor.white : UIColor.black).withAlphaComponent(0.9).cgColor
        label.text = a.name
        label.textColor = dark ? .white : .black
        label.isHidden = !showName
    }
}

/// One train on the Apple map.
final class TrainAnnotation: NSObject, MKAnnotation {
    @objc dynamic var coordinate: CLLocationCoordinate2D
    var point: TrainPoint
    init(_ p: TrainPoint) {
        point = p
        coordinate = CLLocationCoordinate2D(latitude: p.lat, longitude: p.lon)
    }
}

/// A train's marker: the Clack map's disc (with the heading cone when known), a label under it from zoom 9, and a
/// ring when selected, followed, yours or on the shown corridor.
final class TrainAnnotationView: MKAnnotationView {
    static let reuseId = "train"
    private let picture = UIImageView()
    private let ring = UIView()
    private let label = UILabel()
    private static var images: [String: UIImage] = [:]

    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        frame = CGRect(x: 0, y: 0, width: 28, height: 28)
        collisionMode = .none
        displayPriority = .required
        ring.frame = bounds.insetBy(dx: -4, dy: -4)
        ring.layer.cornerRadius = ring.bounds.width / 2
        ring.layer.borderWidth = 2
        ring.isHidden = true
        addSubview(ring)
        picture.frame = bounds
        picture.contentMode = .scaleAspectFit
        addSubview(picture)
        label.font = UIFont.systemFont(ofSize: 11, weight: .semibold)
        label.textAlignment = .center
        label.frame = CGRect(x: -36, y: 28, width: 100, height: 14)
        addSubview(label)
    }

    required init?(coder: NSCoder) { fatalError() }

    /// The marker picture per colour, drawn once (the MapLibre style draws the same picture at half size).
    private static func image(color: String, heading: Bool) -> UIImage {
        let key = "\(color)|\(heading)"
        if let img = images[key] { return img }
        let img = LiveMapImages.train(color: UIColor(cssColor: color), heading: heading)
        images[key] = img
        return img
    }

    func apply(_ p: TrainPoint, selected: Bool, corridor: Bool, showLabel: Bool, dark: Bool) {
        picture.image = Self.image(color: p.color, heading: p.bearing != nil)
        picture.transform = p.bearing.map { CGAffineTransform(rotationAngle: $0 * .pi / 180) } ?? .identity
        label.text = p.label
        label.textColor = dark ? .white : .black
        label.isHidden = !showLabel
        let ringColor: UIColor? = selected ? .white : corridor ? UIColor(cssColor: MapStyle.corridorColor) : p.mine ? UIColor(cssColor: "#f8d64a") : p.followed ? (dark ? .white : .black) : nil
        ring.isHidden = ringColor == nil
        ring.layer.borderColor = ringColor?.cgColor
        ring.backgroundColor = p.mine && !selected ? UIColor(cssColor: "#f8d64a").withAlphaComponent(0.28) : .clear
    }
}

/// Zoomed out: every train is a dot drawn by one renderer (cheap for a thousand trains).
final class TrainsOverlay: NSObject, MKOverlay {
    var coordinate: CLLocationCoordinate2D { CLLocationCoordinate2D(latitude: 63, longitude: 17) }
    var boundingMapRect: MKMapRect { .world }
}

final class TrainsOverlayRenderer: MKOverlayRenderer {
    /// Shared with the surface: the points to draw, their colours, and whether to draw at all (close zooms use annotations).
    var points: [(point: MKMapPoint, color: CGColor, mine: Bool)] = []
    var enabled = true

    override func canDraw(_ mapRect: MKMapRect, zoomScale: MKZoomScale) -> Bool { enabled }

    override func draw(_ mapRect: MKMapRect, zoomScale: MKZoomScale, in ctx: CGContext) {
        guard enabled else { return }
        let r = 3.0 / zoomScale
        let edge = UIColor.black.withAlphaComponent(0.35).cgColor
        for p in points where mapRect.insetBy(dx: -r * 2, dy: -r * 2).contains(p.point) {
            let radius = p.mine ? r * 1.8 : r
            let box = CGRect(x: p.point.x - radius, y: p.point.y - radius, width: radius * 2, height: radius * 2)
            ctx.setFillColor(edge)
            ctx.fillEllipse(in: box.insetBy(dx: -0.6 / zoomScale, dy: -0.6 / zoomScale))
            ctx.setFillColor(p.color)
            ctx.fillEllipse(in: box)
        }
    }
}

/// A route or corridor line with its own look.
final class StyledPolyline: MKPolyline {
    var color = UIColor.systemBlue
    var dashed = false
    var width: CGFloat = 4
}

@MainActor
final class AppleLiveMapSurface: NSObject, LiveMapSurface, MKMapViewDelegate {
    weak var map: MKMapView?
    let controller: LiveMapController
    var dark = false
    let farOverlay = TrainsOverlay()
    private var farRenderer: TrainsOverlayRenderer?
    private var points: [String: TrainPoint] = [:]
    private var order: [String] = []
    private var annotations: [String: TrainAnnotation] = [:]
    private var selectedId: String?
    private var corridorIds = Set<String>()
    private var routeColor = UIColor.systemBlue
    private var routeLines: [StyledPolyline] = []
    private var corridorLines: [StyledPolyline] = []
    private var display = MapDisplay.load()
    private var railLines: [MKMultiPolyline] = []
    private var stationAnnotations: [StationAnnotation] = []
    /// The rail colour of Apple's own transit view, near enough: solid, no transparency (owner, 2026-10-29).
    static let railBlue = UIColor(red: 0.42, green: 0.60, blue: 0.93, alpha: 1)
    private var readyOnce = false
    private var link: CADisplayLink?
    private var lastFrame: CFTimeInterval = 0
    private var intervals: [Double] = []

    /// Annotation views from this zoom; one overlay of dots below it (the Clack map's `train-far` cut-off).
    private let closeZoom = 7.0
    private let labelZoom = 9.0

    init(controller: LiveMapController) {
        self.controller = controller
    }

    // MARK: the rail network

    /// Clack's rail lines over Apple's map (the trains looked as if they floated; owner 2026-10-29): the same GeoJSON
    /// the MapLibre style uses, as one multipolyline overlay under the trains.
    func loadRailNetwork(_ base: URL) {
        let url = base.appendingPathComponent("api/map/rail-network.geojson")
        Task { [weak self] in
            guard let (data, _) = try? await URLSession.shared.data(from: url) else { return }
            let objects = (try? MKGeoJSONDecoder().decode(data)) ?? []
            var lines: [MKPolyline] = []
            var stations: [StationAnnotation] = []
            for case let f as MKGeoJSONFeature in objects {
                let props = f.properties.flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] } ?? [:]
                for g in f.geometry {
                    if let l = g as? MKPolyline { lines.append(l) }
                    if let m = g as? MKMultiPolyline { lines += m.polylines }
                    if let pt = g as? MKPointAnnotation, let id = props["id"] as? String {
                        stations.append(StationAnnotation(id: id, name: (props["name"] as? String) ?? "", coordinate: pt.coordinate))
                    }
                }
            }
            await MainActor.run {
                guard let self, let map = self.map, !lines.isEmpty else { return }
                let multi = MKMultiPolyline(lines)
                self.railLines = [multi]
                map.addOverlay(multi, level: .aboveRoads)
                self.stationAnnotations = stations
                self.syncStations()
            }
        }
    }

    /// Station dots from zoom 7 (names from 9), as the Clack map; none when the Map settings hide stations.
    private func syncStations() {
        guard let map else { return }
        let want = zoom >= 7 && display.stations
        let shown = map.annotations.contains { $0 is StationAnnotation }
        if want && !shown { map.addAnnotations(stationAnnotations) }
        if !want && shown { map.removeAnnotations(stationAnnotations) }
        if want {
            let names = zoom >= 9 && display.stationNames
            for a in stationAnnotations { (map.view(for: a) as? StationAnnotationView)?.apply(a, showName: names, dark: dark) }
        }
    }

    // MARK: frame measuring

    func startMeasuring() {
        let l = CADisplayLink(target: self, selector: #selector(frame(_:)))
        l.add(to: .main, forMode: .common)
        link = l
    }

    func stopMeasuring() {
        link?.invalidate()
        link = nil
    }

    @objc private func frame(_ l: CADisplayLink) {
        if lastFrame > 0 { intervals.append((l.timestamp - lastFrame) * 1000) }
        lastFrame = l.timestamp
        if intervals.count >= 120 {
            let s = intervals.sorted()
            controller.onFrameStats(s[s.count / 2], s[min(s.count - 1, Int(Double(s.count) * 0.9))], points.count)
            intervals.removeAll(keepingCapacity: true)
        }
    }

    // MARK: zoom and view

    var zoom: Double {
        guard let map, map.bounds.width > 0 else { return 4 }
        return log2(360 * Double(map.bounds.width) / (256 * map.region.span.longitudeDelta))
    }

    var height: CGFloat { map?.bounds.height ?? 600 }

    private var close: Bool { zoom >= closeZoom }

    private func reportView() {
        guard let map, map.bounds.width > 0 else { return }
        let r = map.region
        let bbox = [r.center.longitude - r.span.longitudeDelta / 2, r.center.latitude - r.span.latitudeDelta / 2,
                    r.center.longitude + r.span.longitudeDelta / 2, r.center.latitude + r.span.latitudeDelta / 2]
            .map { String(format: "%.3f", $0) }.joined(separator: ",")
        controller.viewChanged(bbox: bbox, zoom: zoom)
    }

    nonisolated func mapViewDidFinishLoadingMap(_ mapView: MKMapView) {
        MainActor.assumeIsolated {
            guard !readyOnce else { return }
            readyOnce = true
            controller.markReady()
        }
    }

    nonisolated func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
        MainActor.assumeIsolated {
            syncMode()
            syncStations()
            reportView()
        }
    }

    /// Annotations when close, the dot overlay when far; labels from zoom 9.
    private func syncMode() {
        guard let map else { return }
        let wantClose = close && display.trains
        if wantClose && annotations.isEmpty && !points.isEmpty {
            for id in order { if let p = points[id] { add(p, to: map) } }
        } else if !wantClose && !annotations.isEmpty {
            map.removeAnnotations(Array(annotations.values))
            annotations.removeAll()
        }
        farRenderer?.enabled = !wantClose && display.trains
        farRenderer?.setNeedsDisplay()
        let showLabel = zoom >= labelZoom && display.trainLabels
        for (id, a) in annotations {
            (map.view(for: a) as? TrainAnnotationView)?.apply(a.point, selected: id == selectedId, corridor: corridorIds.contains(id), showLabel: showLabel, dark: dark)
        }
    }

    private func add(_ p: TrainPoint, to map: MKMapView) {
        let a = TrainAnnotation(p)
        annotations[p.id] = a
        map.addAnnotation(a)
    }

    // MARK: trains

    func setTrains(_ newPoints: [TrainPoint]) {
        guard let map else { return }
        var seen = Set<String>()
        order = newPoints.map(\.id)
        for p in newPoints {
            seen.insert(p.id)
            points[p.id] = p
            if let a = annotations[p.id] {
                a.point = p
                // On screen and close, the glide frames (`moveTrains`) carry it to the new spot; jumping it here
                // first and then gliding from the old spot made the trains jitter (owner, 2026-10-29).
                let target = CLLocationCoordinate2D(latitude: p.lat, longitude: p.lon)
                if !close || !contains(a.coordinate.latitude, a.coordinate.longitude) { a.coordinate = target }
            } else if close && display.trains {
                add(p, to: map)
            }
        }
        for id in Array(points.keys) where !seen.contains(id) {
            points[id] = nil
            if let a = annotations.removeValue(forKey: id) { map.removeAnnotation(a) }
        }
        farRenderer?.points = newPoints.map { (MKMapPoint(CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lon)), UIColor(cssColor: $0.color).cgColor, $0.mine) }
        syncMode()
    }

    func moveTrains(_ positions: [String: LatLon]) {
        for (id, pos) in positions {
            annotations[id]?.coordinate = CLLocationCoordinate2D(latitude: pos.lat, longitude: pos.lon)
            if var p = points[id] {
                p.lat = pos.lat
                p.lon = pos.lon
                points[id] = p
            }
        }
        if !close { farRenderer?.points = order.compactMap { points[$0] }.map { (MKMapPoint(CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lon)), UIColor(cssColor: $0.color).cgColor, $0.mine) }; farRenderer?.setNeedsDisplay() }
    }

    func setSelected(_ id: String?) {
        selectedId = id
        syncMode()
    }

    nonisolated func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        MainActor.assumeIsolated {
            if let st = annotation as? StationAnnotation {
                let v = (mapView.dequeueReusableAnnotationView(withIdentifier: StationAnnotationView.reuseId) as? StationAnnotationView) ?? StationAnnotationView(annotation: st, reuseIdentifier: StationAnnotationView.reuseId)
                v.annotation = st
                v.apply(st, showName: zoom >= labelZoom && display.stationNames, dark: dark)
                return v
            }
            guard let a = annotation as? TrainAnnotation else { return nil }
            let v = mapView.dequeueReusableAnnotationView(withIdentifier: TrainAnnotationView.reuseId, for: a) as! TrainAnnotationView
            v.apply(a.point, selected: a.point.id == selectedId, corridor: corridorIds.contains(a.point.id), showLabel: zoom >= labelZoom && display.trainLabels, dark: dark)
            return v
        }
    }

    nonisolated func mapView(_ mapView: MKMapView, didSelect annotation: MKAnnotation) {
        MainActor.assumeIsolated {
            mapView.deselectAnnotation(annotation, animated: false)
            if let st = annotation as? StationAnnotation { return controller.onTapStation(st.id, st.name) }
            guard let a = annotation as? TrainAnnotation else { return }
            controller.onTapTrain(a.point.id)
        }
    }

    // MARK: lines

    nonisolated func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        MainActor.assumeIsolated {
            if overlay === farOverlay {
                let r = TrainsOverlayRenderer(overlay: overlay)
                farRenderer = r
                return r
            }
            if let multi = overlay as? MKMultiPolyline {
                let r = MKMultiPolylineRenderer(multiPolyline: multi)
                r.strokeColor = Self.railBlue
                r.lineWidth = 2
                return r
            }
            if let line = overlay as? StyledPolyline {
                let r = MKPolylineRenderer(polyline: line)
                r.strokeColor = line.color
                r.lineWidth = line.width
                r.lineCap = .round
                r.lineJoin = .round
                if line.dashed { r.lineDashPattern = [6, 6] }
                return r
            }
            return MKOverlayRenderer(overlay: overlay)
        }
    }

    private func polyline(_ pts: [LatLon], color: UIColor, dashed: Bool, width: CGFloat) -> StyledPolyline? {
        guard pts.count >= 2 else { return nil }
        let coords = pts.map { CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lon) }
        let l = StyledPolyline(coordinates: coords, count: coords.count)
        l.color = color
        l.dashed = dashed
        l.width = width
        return l
    }

    func setRoute(done: [LatLon], ahead: [LatLon]) {
        guard let map else { return }
        map.removeOverlays(routeLines)
        routeLines = [polyline(done, color: routeColor, dashed: false, width: 4), polyline(ahead, color: routeColor.withAlphaComponent(0.8), dashed: true, width: 3)].compactMap { $0 }
        map.addOverlays(routeLines, level: .aboveRoads)
    }

    func clearRoute() {
        map?.removeOverlays(routeLines)
        routeLines = []
    }

    func setRouteColor(_ hex: String) {
        routeColor = UIColor(cssColor: hex)
    }

    func setCorridor(lines: [[LatLon]], trainIds: [String]) {
        guard let map else { return }
        map.removeOverlays(corridorLines)
        let orange = UIColor(cssColor: MapStyle.corridorColor)
        corridorLines = lines.compactMap { polyline($0, color: orange.withAlphaComponent(0.9), dashed: false, width: 5) }
        map.addOverlays(corridorLines, level: .aboveRoads)
        corridorIds = Set(trainIds)
        syncMode()
    }

    func clearCorridor() {
        map?.removeOverlays(corridorLines)
        corridorLines = []
        corridorIds = []
        syncMode()
    }

    // MARK: camera

    func ease(to c: CLLocationCoordinate2D, minZoom: Double, offset: CGFloat) {
        guard let map, map.bounds.width > 0 else { return }
        let z = max(zoom, minZoom)
        let lonDelta = 360 * Double(map.bounds.width) / (256 * pow(2, z))
        let latDelta = lonDelta * Double(map.bounds.height / map.bounds.width) * cos(c.latitude * .pi / 180)
        let metersPerPoint = lonDelta * 111_320 * cos(c.latitude * .pi / 180) / Double(map.bounds.width)
        let shifted = CLLocationCoordinate2D(latitude: c.latitude - Double(offset) * metersPerPoint / 111_320, longitude: c.longitude)
        map.setRegion(MKCoordinateRegion(center: shifted, span: MKCoordinateSpan(latitudeDelta: latDelta, longitudeDelta: lonDelta)), animated: !UIAccessibility.isReduceMotionEnabled)
    }

    func fit(_ pts: [LatLon], padding: UIEdgeInsets) {
        guard let map, let first = pts.first else { return }
        var rect = MKMapRect(origin: MKMapPoint(CLLocationCoordinate2D(latitude: first.lat, longitude: first.lon)), size: MKMapSize(width: 1, height: 1))
        for p in pts.dropFirst() {
            let mp = MKMapPoint(CLLocationCoordinate2D(latitude: p.lat, longitude: p.lon))
            rect = rect.union(MKMapRect(origin: mp, size: MKMapSize(width: 1, height: 1)))
        }
        map.setVisibleMapRect(rect, edgePadding: padding, animated: !UIAccessibility.isReduceMotionEnabled)
        // No closer than zoom 14 (two trains at one station would otherwise fill the screen).
        if zoom > 14 { ease(to: map.region.center, minZoom: 14, offset: 0) }
    }

    func contains(_ lat: Double, _ lon: Double) -> Bool {
        guard let map else { return false }
        let r = map.region
        return abs(lat - r.center.latitude) <= r.span.latitudeDelta / 2 && abs(lon - r.center.longitude) <= r.span.longitudeDelta / 2
    }

    func applyDisplay(_ d: MapDisplay) {
        display = d
        map?.showsUserLocation = d.myLocation
        syncMode()
        syncStations()
    }

    func showUserDot(_ on: Bool) {
        map?.showsUserLocation = on
    }

    func centreOnUser() {
        map?.showsUserLocation = true
        map?.setUserTrackingMode(.follow, animated: !UIAccessibility.isReduceMotionEnabled)
    }
}
