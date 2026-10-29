//
//  LiveMapView.swift
//  Clack
//

import ClackCore
import MapLibre
import ClackDesign
import SwiftUI
import UIKit

/// One train as the map source holds it.
struct TrainPoint {
    var id: String
    var number: String
    var label: String
    /// Where it's going, the label's second line from zoom 11.
    var dest: String? = nil
    var color: String
    var mine: Bool
    var followed: Bool
    var bearing: Double?
    var lat: Double
    var lon: Double
}

/// The map features of the trains on screen, kept between frames so a glide frame only changes coordinates.
@MainActor
struct TrainFeatures {
    private var byId: [String: MLNPointFeature] = [:]
    private(set) var features: [MLNPointFeature] = []

    /// A full picture: every feature is made again (the trains, their colours, the filters or the follows changed).
    mutating func rebuild(_ points: [TrainPoint]) -> [MLNPointFeature] {
        byId.removeAll(keepingCapacity: true)
        features = points.map { p in
            let f = MLNPointFeature()
            f.coordinate = CLLocationCoordinate2D(latitude: p.lat, longitude: p.lon)
            f.attributes = [
                "id": p.id, "number": p.number, "label": p.label, "dest": p.dest ?? "", "color": p.color, "mine": p.mine, "followed": p.followed,
                "bearing": p.bearing ?? 0, "hasBearing": p.bearing != nil,
            ]
            byId[p.id] = f
            return f
        }
        return features
    }

    /// Moves the features that are here; a train that isn't drawn (filtered out) is ignored.
    func move(_ positions: [String: LatLon]) {
        for (id, position) in positions {
            byId[id]?.coordinate = CLLocationCoordinate2D(latitude: position.lat, longitude: position.lon)
        }
    }
}

/// What the Explore screen does to its map, and what the map tells the screen.
@MainActor
final class LiveMapController {
    weak var mapView: MLNMapView?
    private(set) var ready = false
    var onTapTrain: (String) -> Void = { _ in }
    var onTapStation: (_ id: String, _ name: String) -> Void = { _, _ in }
    /// The visible area as "W,S,E,N" (3 decimals) and the zoom, after the map settles.
    var onViewChange: (_ bbox: String, _ zoom: Double) -> Void = { _, _ in }
    var onReady: () -> Void = {}
    /// A new map view was made (its style isn't loaded yet).
    var onRebuild: () -> Void = {}
    /// The Apple test engine's frame interval (median ms, p90 ms) and how many trains it holds, about once a second.
    var onFrameStats: (_ medianMs: Double, _ p90Ms: Double, _ trains: Int) -> Void = { _, _, _ in }

    /// Another engine standing in for MapLibre (Explore on Apple Maps, BUILDOUT O3): while set, every call goes to it.
    var surface: LiveMapSurface?

    private var reduceMotion: Bool { UIAccessibility.isReduceMotionEnabled }

    /// What the map shows (Explore's filter panel, Map section): set by the screen, applied whenever the style is ready.
    var display = MapDisplay.load() { didSet { applyDisplay() } }

    /// Your position on the map: MapLibre's own dot, there once iOS has allowed it unless switched off in the Map
    /// settings, and the camera is left where it is.
    func showUserDot() {
        if let surface { return surface.showUserDot(display.myLocation) }
        mapView?.showsUserLocation = display.myLocation
    }

    /// Shows or hides the layers the Map settings name: trains, train labels, station dots, station names, your dot.
    func applyDisplay() {
        if let surface { return surface.applyDisplay(display) }
        guard let map = mapView, let style = map.style else { return }
        let groups: [(ids: [String], on: Bool)] = [
            (["train-far", "train-dot", "train-mine", "train-followed", "train-selected"], display.trains),
            (["train-label"], display.trains && display.trainLabels),
            (["live-stations", "rail-stations"], display.stations),
            (["live-station-labels"], display.stationNames),
        ]
        for g in groups { for id in g.ids { style.layer(withIdentifier: id)?.isVisible = g.on } }
        if !display.myLocation { map.showsUserLocation = false }
    }

    /// The locate button: centres on you, at least at zoom 11, and follows you until you move the map yourself.
    func centreOnUser() {
        if let surface { return surface.centreOnUser() }
        guard let map = mapView else { return }
        map.showsUserLocation = true
        (map as? ClackMapView)?.markMoved()
        if map.zoomLevel < 11, let here = map.userLocation?.location?.coordinate, CLLocationCoordinate2DIsValid(here), here.latitude != 0 {
            map.setCenter(here, zoomLevel: 12, animated: !reduceMotion)
        } else {
            map.setUserTrackingMode(.follow, animated: !reduceMotion, completionHandler: nil)
        }
    }

    /// Draws the map again (it pauses while out of the window).
    func repaint() {
        guard surface == nil, let map = mapView else { return }
        map.isHidden = false
        map.setNeedsLayout()
        map.triggerRepaint()
    }

    func rebuilt() {
        ready = false
        onRebuild()
    }

    /// The Apple surface's view settled.
    func viewChanged(bbox: String, zoom: Double) {
        onViewChange(bbox, zoom)
    }

    func markReady() {
        ready = true
        applyDisplay()
        onReady()
        reportView()
    }

    fileprivate func reportView() {
        guard let map = mapView, map.bounds.width > 0 else { return }
        let b = map.visibleCoordinateBounds
        let bbox = [b.sw.longitude, b.sw.latitude, b.ne.longitude, b.ne.latitude].map { String(format: "%.3f", $0) }.joined(separator: ",")
        onViewChange(bbox, map.zoomLevel)
    }

    var zoom: Double { surface?.zoom ?? mapView?.zoomLevel ?? 4 }

    /// Every visible train, at the position it is drawn at now.
    func setTrains(_ points: [TrainPoint]) {
        if let surface { return surface.setTrains(points) }
        guard let source = mapView?.style?.source(withIdentifier: "trains") as? MLNShapeSource else { return }
        source.shape = MLNShapeCollectionFeature(shapes: trainFeatures.rebuild(points))
        // Your own trains and the ones you follow are also kept out of the clusters, so they stay marked when zoomed out.
        if let pinned = mapView?.style?.source(withIdentifier: "trains-pinned") as? MLNShapeSource {
            pinned.shape = MLNShapeCollectionFeature(shapes: pinnedFeatures.rebuild(points.filter { $0.mine || $0.followed }))
        }
    }

    /// A glide frame: only the trains that are moving get a new coordinate; every other feature is reused as it was.
    func moveTrains(_ positions: [String: LatLon]) {
        if let surface { return surface.moveTrains(positions) }
        guard let source = mapView?.style?.source(withIdentifier: "trains") as? MLNShapeSource else { return }
        trainFeatures.move(positions)
        source.shape = MLNShapeCollectionFeature(shapes: trainFeatures.features)
    }

    private var trainFeatures = TrainFeatures()
    private var pinnedFeatures = TrainFeatures()

    func setSelected(_ id: String?) {
        if let surface { return surface.setSelected(id) }
        (mapView?.style?.layer(withIdentifier: "train-selected") as? MLNCircleStyleLayer)?.predicate = NSPredicate(format: "id == %@", id ?? "")
    }

    /// The route in the train's colour: travelled part solid, the rest dashed.
    func setRoute(done: [LatLon], ahead: [LatLon]) {
        if let surface { return surface.setRoute(done: done, ahead: ahead) }
        mapView?.setShape(MapGeometry.lines([done]), source: "route")
        mapView?.setShape(MapGeometry.lines([ahead]), source: "route-ahead")
    }

    func clearRoute() {
        if let surface { return surface.clearRoute() }
        for id in ["route", "route-ahead", "route-context"] { mapView?.setShape(MapGeometry.lines([]), source: id) }
    }

    /// A corridor from the network status: its track in orange and a ring on each of its late trains.
    func setCorridor(lines: [[LatLon]], trainIds: [String]) {
        if let surface { return surface.setCorridor(lines: lines, trainIds: trainIds) }
        mapView?.setShape(MapGeometry.lines(lines), source: "corridor")
        (mapView?.style?.layer(withIdentifier: "train-corridor") as? MLNCircleStyleLayer)?.predicate = NSPredicate(format: "id IN %@", trainIds)
    }

    func clearCorridor() {
        if let surface { return surface.clearCorridor() }
        mapView?.setShape(MapGeometry.lines([]), source: "corridor")
        (mapView?.style?.layer(withIdentifier: "train-corridor") as? MLNCircleStyleLayer)?.predicate = NSPredicate(format: "id == %@", "")
    }

    func setRouteColor(_ hex: String) {
        if let surface { return surface.setRouteColor(hex) }
        guard let style = mapView?.style else { return }
        let color = UIColor(cssColor: hex)
        for id in ["route-context", "route-ahead", "route-glow", "route-body"] {
            (style.layer(withIdentifier: id) as? MLNLineStyleLayer)?.lineColor = NSExpression(forConstantValue: color)
        }
        (style.layer(withIdentifier: "route-core") as? MLNLineStyleLayer)?.lineColor = NSExpression(forConstantValue: UIColor(cssColor: MapStyle.lighten(hex, 0.55)))
        (style.layer(withIdentifier: "stops-end") as? MLNCircleStyleLayer)?.circleColor = NSExpression(forConstantValue: color)
    }

    /// Eases to a train, up into the free space above its sheet: at least `minZoom`, with the point `offset` points above
    /// the middle.
    func ease(to c: CLLocationCoordinate2D, minZoom: Double, offset: CGFloat) {
        if let surface { return surface.ease(to: c, minZoom: minZoom, offset: offset) }
        guard let map = mapView else { return }
        (map as? ClackMapView)?.markMoved()
        let z = max(map.zoomLevel, minZoom)
        let metersPerPoint = map.metersPerPoint(atLatitude: c.latitude) * pow(2, map.zoomLevel - z)
        let shifted = CLLocationCoordinate2D(latitude: c.latitude - Double(offset) * metersPerPoint / 111_320, longitude: c.longitude)
        map.setCenter(shifted, zoomLevel: z, animated: !reduceMotion)
    }

    func fit(_ points: [LatLon], padding: UIEdgeInsets) {
        if let surface { return surface.fit(points, padding: padding) }
        (mapView as? ClackMapView)?.markMoved()
        mapView?.fit(points, padding: padding, maxZoom: 14, animated: !reduceMotion)
    }

    var height: CGFloat { surface?.height ?? mapView?.bounds.height ?? 600 }

    /// Whether any train marker is inside the current view (for deciding who glides).
    func contains(_ lat: Double, _ lon: Double) -> Bool {
        if let surface { return surface.contains(lat, lon) }
        guard let b = mapView?.visibleCoordinateBounds else { return false }
        return lat >= b.sw.latitude && lat <= b.ne.latitude && lon >= b.sw.longitude && lon <= b.ne.longitude
    }
}

/// The live map (LiveMapPage.tsx): the basemap and rail network, stations you can tap, every running train as a marker
/// (clustered when zoomed out) and the selected train's route.
struct LiveMapView: UIViewRepresentable {
    let controller: LiveMapController
    let base: URL
    let withBasemap: Bool
    let dark: Bool

    func makeCoordinator() -> Coordinator { Coordinator(controller: controller, dark: dark) }

    func makeUIView(context: Context) -> MLNMapView {
        let style = MapStyle.style(base: base, withBasemap: withBasemap, dark: dark, railNetwork: true, kind: .live)
        let url = (try? MapStyle.write(style)) ?? URL(fileURLWithPath: "/dev/null")
        let map = ClackMapView(frame: .zero, styleURL: url)
        map.applyClackDefaults()
        map.delegate = context.coordinator
        // Opens on Sweden, Norway, Finland and Denmark, Bergen to the Finnish east border, Gedser to Nordkapp. The map may be built before it has a
        // size (Explore is built at launch), so the framing is kept and applied when it gets one.
        map.setCenter(CLLocationCoordinate2D(latitude: 63, longitude: 17), zoomLevel: 3.8, animated: false)
        map.wantedFit = ClackMapView.Fit(points: [LatLon(54.5, 4.5), LatLon(70.2, 31.7)], padding: .zero, maxZoom: 14)
        controller.mapView = map
        controller.surface = nil
        controller.rebuilt()
        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.tapped(_:)))
        tap.delegate = context.coordinator
        // Only a double tap (zoom) and a two-finger tap (zoom out) may win over a tap. The map's own single tap
        // recognizer (it selects annotations) succeeds on every tap, so waiting for it to fail would swallow ours.
        for recognizer in map.gestureRecognizers ?? [] {
            if let other = recognizer as? UITapGestureRecognizer, other.numberOfTapsRequired > 1 || other.numberOfTouchesRequired > 1 {
                tap.require(toFail: other)
            }
        }
        map.addGestureRecognizer(tap)
        return map
    }

    func updateUIView(_ map: MLNMapView, context: Context) {}

    @MainActor
    final class Coordinator: NSObject, MLNMapViewDelegate, UIGestureRecognizerDelegate {
        let controller: LiveMapController
        let dark: Bool

        init(controller: LiveMapController, dark: Bool) {
            self.controller = controller
            self.dark = dark
        }

        func mapView(_ mapView: MLNMapView, didFinishLoading style: MLNStyle) {
            controller.markReady()
        }

        func mapView(_ mapView: MLNMapView, regionWillChangeWith reason: MLNCameraChangeReason, animated: Bool) {
            // The person moved the map: it keeps where they put it.
            if reason.contains(.gesturePan) || reason.contains(.gesturePinch) || reason.contains(.gestureZoomIn) || reason.contains(.gestureZoomOut) {
                (mapView as? ClackMapView)?.markMoved()
            }
        }

        func mapView(_ mapView: MLNMapView, regionDidChangeAnimated animated: Bool) {
            controller.reportView()
        }

        // MARK: images, drawn on demand (the web's `styleimagemissing`)

        func mapView(_ mapView: MLNMapView, didFailToLoadImage imageName: String) -> UIImage? {
            let c = MapStyle.colors(dark: dark)
            if imageName == "station" { return LiveMapImages.station(fill: UIColor(cssColor: c.bg), line: UIColor(cssColor: c.text)) }
            if imageName == "cluster" { return LiveMapImages.cluster(light: !dark) }
            if imageName.hasPrefix("tdot-") { return LiveMapImages.train(color: UIColor(cssColor: String(imageName.dropFirst(5))), heading: false) }
            if imageName.hasPrefix("tpuck-") { return LiveMapImages.train(color: UIColor(cssColor: String(imageName.dropFirst(6))), heading: true) }
            return nil
        }

        // MARK: taps

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool { true }

        @objc func tapped(_ gesture: UITapGestureRecognizer) {
            guard let map = gesture.view as? MLNMapView else { return }
            let point = gesture.location(in: map)
            // A fingertip is wider than the dot: 32 pt square, and the nearest dot to the finger wins.
            let box = CGRect(x: point.x - 16, y: point.y - 16, width: 32, height: 32)
            // Clusters zoom in two levels at the tap.
            if !map.visibleFeatures(at: point, styleLayerIdentifiers: ["clusters"]).isEmpty {
                let at = map.convert(point, toCoordinateFrom: map)
                map.setCenter(at, zoomLevel: map.zoomLevel + 2, animated: !UIAccessibility.isReduceMotionEnabled)
                return
            }
            // Trains bunch up at stations: of the dots under the finger, take the one nearest to it.
            let trains = map.visibleFeatures(in: box, styleLayerIdentifiers: ["train-dot"])
            if let best = trains.min(by: { distance($0, point, map) < distance($1, point, map) }), let id = best.attribute(forKey: "id") as? String {
                controller.onTapTrain(id)
                return
            }
            // A station's name always opens it (its square can sit under a train).
            func station(_ layer: String, in area: CGRect) -> (String, String)? {
                guard let f = map.visibleFeatures(in: area, styleLayerIdentifiers: [layer]).first,
                      let id = f.attribute(forKey: "id") as? String else { return nil }
                return (id, (f.attribute(forKey: "name") as? String) ?? "")
            }
            if let (id, name) = station("live-station-labels", in: CGRect(x: point.x, y: point.y, width: 0.1, height: 0.1)) {
                controller.onTapStation(id, name)
            } else if let (id, name) = station("live-stations", in: box) {
                controller.onTapStation(id, name)
            }
        }

        private func distance(_ f: MLNFeature, _ point: CGPoint, _ map: MLNMapView) -> CGFloat {
            let p = map.convert(f.coordinate, toPointTo: map)
            return hypot(p.x - point.x, p.y - point.y)
        }
    }
}

/// The marker pictures (LiveMapPage.tsx `trainMarkerImage`, `clusterImage`, `stationImage`), drawn at pixel ratio 2.
enum LiveMapImages {
    private static func render(_ size: CGFloat, _ draw: (CGContext) -> Void) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 2
        format.opaque = false
        return UIGraphicsImageRenderer(size: CGSize(width: size / 2, height: size / 2), format: format).image { ctx in
            // Drawn in the web's canvas pixels.
            ctx.cgContext.scaleBy(x: 0.5, y: 0.5)
            draw(ctx.cgContext)
        }
    }

    /// A train, in Apple Maps' language: a flat disc in the operator colour with a white ring and a soft shadow, no
    /// gloss. With a known heading it carries the translucent cone Apple uses for your own location, pointing up and
    /// rotated to the bearing on the map. The disc's centre is the image centre. 96 px.
    static func train(color: UIColor, heading: Bool) -> UIImage {
        render(96) { g in
            let c = CGPoint(x: 48, y: 48)
            if heading {
                g.saveGState()
                let wedge = UIBezierPath()
                wedge.move(to: c)
                wedge.addArc(withCenter: c, radius: 46, startAngle: -.pi / 2 - 0.55, endAngle: -.pi / 2 + 0.55, clockwise: true)
                wedge.close()
                g.addPath(wedge.cgPath)
                g.clip()
                let colors = [color.withAlphaComponent(0.5).cgColor, color.withAlphaComponent(0).cgColor] as CFArray
                if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1]) {
                    g.drawRadialGradient(gradient, startCenter: c, startRadius: 10, endCenter: c, endRadius: 46, options: [])
                }
                g.restoreGState()
            }
            g.saveGState()
            g.setShadow(offset: CGSize(width: 0, height: -1.5), blur: 6, color: UIColor.black.withAlphaComponent(0.35).cgColor)
            g.setFillColor(UIColor.white.cgColor)
            g.fillEllipse(in: CGRect(x: c.x - 15.5, y: c.y - 15.5, width: 31, height: 31))
            g.restoreGState()
            g.setFillColor(color.cgColor)
            g.fillEllipse(in: CGRect(x: c.x - 12, y: c.y - 12, width: 24, height: 24))
        }
    }

    /// Several trains: a flat material circle with a hairline white edge and a soft shadow (the count is drawn on top).
    static func cluster(light: Bool) -> UIImage {
        render(76) { g in
            let rect = CGRect(x: 38 - 27, y: 38 - 27, width: 54, height: 54)
            g.saveGState()
            g.setShadow(offset: CGSize(width: 0, height: -2), blur: 8, color: UIColor.black.withAlphaComponent(0.3).cgColor)
            g.setFillColor((light ? UIColor.white.withAlphaComponent(0.96) : UIColor(red: 44 / 255, green: 44 / 255, blue: 46 / 255, alpha: 0.94)).cgColor)
            g.fillEllipse(in: rect)
            g.restoreGState()
            g.setLineWidth(2)
            g.setStrokeColor((light ? UIColor.black.withAlphaComponent(0.08) : UIColor.white.withAlphaComponent(0.55)).cgColor)
            g.strokeEllipse(in: rect)
        }
    }

    /// Stations are small rounded squares, so they never read as a train's round dot. 20 px.
    static func station(fill: UIColor, line: UIColor) -> UIImage {
        render(20) { g in
            let path = UIBezierPath(roundedRect: CGRect(x: 3, y: 3, width: 14, height: 14), cornerRadius: 3)
            g.setFillColor(fill.cgColor)
            g.setStrokeColor(line.cgColor)
            g.setLineWidth(3)
            g.addPath(path.cgPath)
            g.drawPath(using: .fillStroke)
        }
    }
}

/// Explore's map display settings (owner, 2026-10-27): each part can be switched off, so a trains-only or a
/// stations-only map is possible. Remembered between launches; the train filters are not.
struct MapDisplay: Codable, Equatable {
    var myLocation = true
    var trains = true
    var trainLabels = true
    var stations = true
    var stationNames = true
    /// What the train dots' colours mean (owner, 2026-10-28).
    var colorBy = ExploreLogic.ColorBy.operatorBrand

    init() {}

    /// Settings saved before a setting existed keep the others and take that one's default.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        myLocation = try c.decodeIfPresent(Bool.self, forKey: .myLocation) ?? true
        trains = try c.decodeIfPresent(Bool.self, forKey: .trains) ?? true
        trainLabels = try c.decodeIfPresent(Bool.self, forKey: .trainLabels) ?? true
        stations = try c.decodeIfPresent(Bool.self, forKey: .stations) ?? true
        stationNames = try c.decodeIfPresent(Bool.self, forKey: .stationNames) ?? true
        colorBy = (try? c.decodeIfPresent(ExploreLogic.ColorBy.self, forKey: .colorBy)) ?? .operatorBrand
    }

    private static let key = "explore.mapDisplay"

    static func load() -> MapDisplay {
        guard let data = UserDefaults.standard.data(forKey: key), let d = try? JSONDecoder().decode(MapDisplay.self, from: data) else { return MapDisplay() }
        return d
    }

    func save() {
        if let data = try? JSONEncoder().encode(self) { UserDefaults.standard.set(data, forKey: Self.key) }
    }
}
