//
//  RouteMapView.swift
//  Clack
//

import MapLibre
import SwiftUI

/// What the map controls act on: the map view, once it exists.
@MainActor
final class MapHandle {
    weak var mapView: MLNMapView?
    var fitPoints: [LatLon] = []
    var padding = MapPadding.interactive

    func recenter() {
        mapView?.fit(fitPoints, padding: padding, maxZoom: 13, animated: !UIAccessibility.isReduceMotionEnabled)
    }
}

/// A route map (DESIGN §2.4): the basemap, the ridden route as a glowing line in the operator colour, stop dots, an
/// optional faint rest-of-route, the rail-network toggle and a draw-on animation. While a train is live it also shows
/// the train marker, the part still ahead as a dimmed dashed line, and Follow train (apps/web/src/map/RouteMap.tsx).
struct RouteMapView: View {
    @Environment(AppModel.self) private var app
    @Environment(L10n.self) private var l10n
    @Environment(\.colorScheme) private var scheme

    /// The operator's colour as a hex string.
    let color: String
    let route: [LatLon]
    /// Parts of the train's route you didn't ride, drawn faintly (the confirm step).
    var context: [[LatLon]] = []
    let stops: [MapStop]
    var animate = false
    var interactive = true
    var controls = true
    var railNetwork = false
    var train: MapTrain?
    /// Share of the route already travelled (0 to 1): splits the line into travelled and ahead.
    var progress: Double?
    var label: String?
    /// Space the controls keep from the top edge (the status bar, when the map runs under it).
    var topInset: CGFloat = 0
    /// Space the bottom controls keep from the bottom edge (the sheet that overlaps a trip's map).
    var bottomInset: CGFloat = 0

    @State private var handle = MapHandle()
    @State private var showRail: Bool
    @State private var follow = false
    @State private var basemap: Bool?

    init(
        color: String, route: [LatLon], context: [[LatLon]] = [], stops: [MapStop], animate: Bool = false, interactive: Bool = true,
        controls: Bool = true, railNetwork: Bool = false, train: MapTrain? = nil, progress: Double? = nil, label: String? = nil,
        topInset: CGFloat = 0, bottomInset: CGFloat = 0
    ) {
        self.color = color
        self.route = route
        self.context = context
        self.stops = stops
        self.animate = animate
        self.interactive = interactive
        self.controls = controls
        self.railNetwork = railNetwork
        self.train = train
        self.progress = progress
        self.label = label
        self.topInset = topInset
        self.bottomInset = bottomInset
        _showRail = State(initialValue: railNetwork)
    }

    var body: some View {
        ZStack {
            Ink.mapBg
            if let basemap {
                RouteMapRepresentable(
                    handle: handle, base: Config.apiBase, color: color, route: route, context: context, stops: stops,
                    animate: animate, interactive: interactive, controls: controls, showRail: showRail, follow: $follow,
                    train: train, progress: progress, withBasemap: basemap, dark: scheme == .dark
                )
                // Re-created when the theme changes: the basemap and every layer take their colours from it.
                .id("\(scheme == .dark)-\(basemap)")
            }
            if controls && interactive {
                VStack {
                    HStack {
                        Spacer()
                        VStack(spacing: 8) {
                            MapButton(icon: "layers", label: l10n.t("map.railNetwork"), pressed: showRail) { showRail.toggle() }
                            if train != nil {
                                MapButton(icon: "navigation", label: l10n.t("live.follow"), pressed: follow) { follow.toggle() }
                            }
                        }
                    }
                    .padding(.top, 12 + topInset)
                    Spacer()
                    HStack {
                        Spacer()
                        MapButton(icon: "locate-fixed", label: l10n.t("map.recenter")) {
                            follow = false
                            handle.recenter()
                        }
                    }
                    .padding(.bottom, 16 + bottomInset)
                }
                .padding(.trailing, 16)
            }
            VStack {
                Spacer()
                HStack {
                    Text("© OpenStreetMap contributors · Protomaps")
                        .clack(.mapAttribution).foregroundStyle(Ink.text3)
                        .padding(.leading, 8).padding(.bottom, 6 + bottomInset)
                        .allowsHitTesting(false)
                    Spacer()
                }
            }
        }
        .clipped()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label ?? "")
        .task { basemap = await app.mapHasBasemap() }
    }
}

private struct RouteMapRepresentable: UIViewRepresentable {
    let handle: MapHandle
    let base: URL
    let color: String
    let route: [LatLon]
    let context: [[LatLon]]
    let stops: [MapStop]
    let animate: Bool
    let interactive: Bool
    let controls: Bool
    let showRail: Bool
    @Binding var follow: Bool
    let train: MapTrain?
    let progress: Double?
    let withBasemap: Bool
    let dark: Bool

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context ctx: Context) -> MLNMapView {
        let style = MapStyle.style(base: base, withBasemap: withBasemap, dark: dark, railNetwork: showRail, kind: .route(color: color))
        let url = (try? MapStyle.write(style)) ?? URL(fileURLWithPath: "/dev/null")
        let map = ClackMapView(frame: .zero, styleURL: url)
        map.applyClackDefaults()
        map.delegate = ctx.coordinator
        map.isUserInteractionEnabled = interactive
        map.setCenter(CLLocationCoordinate2D(latitude: 62, longitude: 15), zoomLevel: 4, animated: false)
        ctx.coordinator.map = map
        handle.mapView = map
        handle.padding = controls && interactive ? MapPadding.interactive : MapPadding.mini
        handle.fitPoints = route.isEmpty ? stops.map { LatLon($0.lat, $0.lon) } : route
        return map
    }

    func updateUIView(_ map: MLNMapView, context ctx: Context) {
        ctx.coordinator.parent = self
        ctx.coordinator.update(map)
    }

    @MainActor
    final class Coordinator: NSObject, MLNMapViewDelegate {
        var parent: RouteMapRepresentable
        weak var map: MLNMapView?
        private var styleLoaded = false
        private var lastRouteKey = ""
        private var lastProgressKey = ""
        private var railOn: Bool
        private var annotation: MLNPointAnnotation?
        private var drawLink: CADisplayLink?
        private var drawStart: CFTimeInterval = 0
        private var drawing = false

        init(_ parent: RouteMapRepresentable) {
            self.parent = parent
            railOn = parent.showRail
        }

        deinit { drawLink?.invalidate() }

        private var reduceMotion: Bool { UIAccessibility.isReduceMotionEnabled }

        func mapView(_ mapView: MLNMapView, didFinishLoading style: MLNStyle) {
            styleLoaded = true
            let p = parent
            let draw = p.animate && !reduceMotion && p.route.count > 1 && p.progress == nil
            mapView.setShape(MapGeometry.lines(p.context), source: "route-context")
            mapView.setShape(MapGeometry.lines([]), source: "route-ahead")
            mapView.setShape(MapGeometry.lines([draw ? Array(p.route.prefix(1)) : p.route]), source: "route")
            mapView.setShape(MapGeometry.points(draw ? Array(p.stops.filter { $0.kind == .end }.prefix(1)) : p.stops), source: "stops")
            lastRouteKey = routeKey(p)
            let fitPoints = p.route.isEmpty ? p.stops.map { LatLon($0.lat, $0.lon) } : p.route
            mapView.fit(fitPoints, padding: p.controls && p.interactive ? MapPadding.interactive : MapPadding.mini, maxZoom: 13, animated: false)
            if draw { startDrawOn(mapView) } else { applyProgress(mapView) }
            updateTrain(mapView)
        }

        func mapView(_ mapView: MLNMapView, regionWillChangeWith reason: MLNCameraChangeReason, animated: Bool) {
            // Dragging the map means you want to look around: stop following the train.
            if reason.contains(.gesturePan) || reason.contains(.gesturePinch) {
                (mapView as? ClackMapView)?.markMoved()
                DispatchQueue.main.async { self.parent.follow = false }
            }
        }

        func mapView(_ mapView: MLNMapView, viewFor annotation: MLNAnnotation) -> MLNAnnotationView? {
            guard annotation is MLNPointAnnotation else { return nil }
            let id = "train"
            let view = (mapView.dequeueReusableAnnotationView(withIdentifier: id) as? TrainMarkerView) ?? TrainMarkerView(reuseIdentifier: id)
            if let train = parent.train {
                let ui = UIColor(Color(hex: parent.color) ?? .yellow)
                view.configure(color: ui, estimated: train.estimated, bearing: train.bearing)
            }
            return view
        }

        private func routeKey(_ p: RouteMapRepresentable) -> String {
            "\(p.route.count):\(p.route.first.map { "\($0.lat),\($0.lon)" } ?? ""):\(p.route.last.map { "\($0.lat),\($0.lon)" } ?? ""):\(p.context.count):\(p.stops.count)"
        }

        func update(_ map: MLNMapView) {
            guard styleLoaded else { return }
            let p = parent
            let key = routeKey(p)
            if key != lastRouteKey {
                lastRouteKey = key
                map.setShape(MapGeometry.lines(p.context), source: "route-context")
                map.setShape(MapGeometry.points(p.stops), source: "stops")
                let fitPoints = p.route.isEmpty ? p.stops.map { LatLon($0.lat, $0.lon) } : p.route
                p.handle.fitPoints = fitPoints
                if !p.follow { map.fit(fitPoints, padding: p.handle.padding, maxZoom: 13, animated: !reduceMotion) }
                applyProgress(map)
            }
            let progressKey = p.progress.map { String(format: "%.4f", $0) } ?? "none"
            if progressKey != lastProgressKey { applyProgress(map) }
            updateRail(map)
            updateTrain(map)
        }

        /// Travelled vs ahead (live) or the whole line.
        private func applyProgress(_ map: MLNMapView) {
            guard !drawing else { return }
            let p = parent
            lastProgressKey = p.progress.map { String(format: "%.4f", $0) } ?? "none"
            if let progress = p.progress {
                let (done, ahead) = MapGeometry.split(p.route, at: progress)
                map.setShape(MapGeometry.lines([done]), source: "route")
                map.setShape(MapGeometry.lines([ahead]), source: "route-ahead")
            } else {
                map.setShape(MapGeometry.lines([p.route]), source: "route")
                map.setShape(MapGeometry.lines([]), source: "route-ahead")
            }
        }

        /// The rail network layer, added the first time it's switched on, then shown or hidden.
        private func updateRail(_ map: MLNMapView) {
            guard let style = map.style else { return }
            let show = parent.showRail
            if show && style.source(withIdentifier: "rail-network") == nil {
                let source = MLNShapeSource(identifier: "rail-network", url: Config.apiBase.appendingPathComponent("api/map/rail-network.geojson"), options: nil)
                style.addSource(source)
                let colors = MapStyle.colors(dark: parent.dark)
                let lines = MLNLineStyleLayer(identifier: "rail-network", source: source)
                lines.predicate = NSPredicate(format: "$geometryType == 'LineString'")
                lines.lineColor = NSExpression(forConstantValue: UIColor(cssColor: colors.rail))
                lines.lineWidth = NSExpression(forConstantValue: 1)
                let dots = MLNCircleStyleLayer(identifier: "rail-stations", source: source)
                dots.minimumZoomLevel = 9
                dots.circleRadius = NSExpression(forConstantValue: 1.6)
                dots.circleColor = NSExpression(forConstantValue: UIColor(cssColor: colors.railStation))
                if let below = style.layer(withIdentifier: "route-context") {
                    style.insertLayer(lines, below: below)
                    style.insertLayer(dots, below: below)
                } else {
                    style.addLayer(lines)
                    style.addLayer(dots)
                }
            }
            for id in ["rail-network", "rail-stations"] { style.layer(withIdentifier: id)?.isVisible = show }
        }

        /// The train marker, and following it.
        private func updateTrain(_ map: MLNMapView) {
            let p = parent
            guard let train = p.train else {
                if let annotation { map.removeAnnotation(annotation) }
                annotation = nil
                return
            }
            let coordinate = CLLocationCoordinate2D(latitude: train.lat, longitude: train.lon)
            if let annotation {
                annotation.coordinate = coordinate
                if let view = map.view(for: annotation) as? TrainMarkerView {
                    view.configure(color: UIColor(Color(hex: p.color) ?? .yellow), estimated: train.estimated, bearing: train.bearing)
                }
            } else {
                let point = MLNPointAnnotation()
                point.coordinate = coordinate
                annotation = point
                map.addAnnotation(point)
            }
            if p.follow { map.setCenter(coordinate, animated: !reduceMotion) }
        }

        // MARK: draw-on

        private func startDrawOn(_ map: MLNMapView) {
            drawing = true
            drawStart = CACurrentMediaTime()
            let link = CADisplayLink(target: self, selector: #selector(step))
            link.add(to: .main, forMode: .common)
            drawLink = link
        }

        @objc private func step() {
            guard let map else { return }
            let k = min(1, (CACurrentMediaTime() - drawStart) / 1.2)
            let eased = 1 - pow(1 - k, 3)
            map.setShape(MapGeometry.lines([MapGeometry.part(parent.route, eased)]), source: "route")
            if k >= 1 {
                drawLink?.invalidate()
                drawLink = nil
                drawing = false
                map.setShape(MapGeometry.points(parent.stops), source: "stops")
            }
        }
    }
}

extension UIColor {
    /// A CSS colour as the style writes it: `#rrggbb` or `rgba(r,g,b,a)`.
    convenience init(cssColor text: String) {
        if text.hasPrefix("#"), let color = Color(hex: text) {
            self.init(color)
            return
        }
        let numbers = text.drop { $0 != "(" }.dropFirst().dropLast().split(separator: ",").compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }
        if numbers.count == 4 {
            self.init(red: numbers[0] / 255, green: numbers[1] / 255, blue: numbers[2] / 255, alpha: numbers[3])
        } else {
            self.init(white: 0.5, alpha: 1)
        }
    }
}
