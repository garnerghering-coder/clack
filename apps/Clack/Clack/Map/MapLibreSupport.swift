//
//  MapLibreSupport.swift
//  Clack
//

import ClackCore
import MapLibre
import os
import ClackDesign
import SwiftUI
import UIKit

/// The camera padding the web uses (DESIGN): room at the top for the floating buttons and at the sides for labels.
enum MapPadding {
    static let interactive = UIEdgeInsets(top: 72, left: 64, bottom: 96, right: 72)
    static let mini = UIEdgeInsets(top: 28, left: 56, bottom: 28, right: 56)
}

extension MLNMapView {
    /// A map that draws its own attribution and controls: MapLibre's logo, compass and info button are off.
    func applyClackDefaults() {
        attributionButton.isHidden = true
        logoView.isHidden = true
        compassView.isHidden = true
        allowsTilting = false
        automaticallyAdjustsContentInset = false
        backgroundColor = .clear
    }

    /// Sets a GeoJSON source's data. The shape is built directly from the dictionary (`MLNShape.fromGeoJSON`), with no
    /// trip through JSON text, which matters for the route that redraws every frame while it draws itself in.
    func setShape(_ json: [String: Any], source id: String) {
        guard let source = style?.source(withIdentifier: id) as? MLNShapeSource else { return }
        guard let shape = MLNShape.fromGeoJSON(json) else {
            #if DEBUG
            Logger(subsystem: "app.clack", category: "map").error("setShape(\(id, privacy: .public)): the GeoJSON made no shape")
            #endif
            return
        }
        source.shape = shape
    }

    /// Fits the points in the view (zoom no further in than `maxZoom`). A map that hasn't been laid out yet remembers the
    /// fit and applies it as soon as it has a size (`ClackMapView`), so it never stays on the default view.
    func fit(_ points: [LatLon], padding: UIEdgeInsets, maxZoom: Double, animated: Bool) {
        (self as? ClackMapView)?.wantedFit = ClackMapView.Fit(points: points, padding: padding, maxZoom: maxZoom)
        guard let b = MapGeometry.bounds(points), bounds.width > 0, bounds.height > 0 else { return }
        let box = MLNCoordinateBounds(
            sw: CLLocationCoordinate2D(latitude: b.south, longitude: b.west),
            ne: CLLocationCoordinate2D(latitude: b.north, longitude: b.east)
        )
        setVisibleCoordinateBounds(box, edgePadding: padding, animated: animated, completionHandler: nil)
        if zoomLevel > maxZoom { setZoomLevel(maxZoom, animated: false) }
    }
}

/// A map that keeps to the framing it was given (a trip's route, a journey) until the person moves it: if the view had
/// no size when the framing was asked for, or its size changes (the card grows, the phone turns), the framing is
/// applied again. Without this a map could stay on the default view of Sweden.
final class ClackMapView: MLNMapView {
    struct Fit {
        var points: [LatLon]
        var padding: UIEdgeInsets
        var maxZoom: Double
    }

    var wantedFit: Fit?
    private var laidOutSize = CGSize.zero
    private var moved = false

    /// The person panned or zoomed: stop re-applying the framing.
    func markMoved() { moved = true }

    /// Back on screen (Explore's tab shown again, the app back from the background): draw again. MapLibre pauses while
    /// the view is out of the window and doesn't always repaint by itself, which left Explore blank (owner, 2026-10-25).
    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil {
            isHidden = false
            setNeedsLayout()
            triggerRepaint()
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard bounds.width > 0, bounds.height > 0, bounds.size != laidOutSize else { return }
        laidOutSize = bounds.size
        if let wantedFit, !moved {
            fit(wantedFit.points, padding: wantedFit.padding, maxZoom: wantedFit.maxZoom, animated: false)
        }
    }
}

extension MLNShape {
    /// A FeatureCollection of LineString and Point features (all the app draws) as map shapes; anything else goes the
    /// slow way, through JSON, so an unexpected shape still draws.
    static func fromGeoJSON(_ json: [String: Any]) -> MLNShape? {
        guard json["type"] as? String == "FeatureCollection", let features = json["features"] as? [[String: Any]] else {
            return viaJSON(json)
        }
        var shapes: [MLNShape & MLNFeature] = []
        for feature in features {
            guard let geometry = feature["geometry"] as? [String: Any],
                  let coordinates = geometry["coordinates"] as? [Any] else { return viaJSON(json) }
            // MapLibre takes strings, numbers, bools, arrays and dictionaries as attributes, not nulls.
            let attributes = (feature["properties"] as? [String: Any] ?? [:]).filter { !($0.value is NSNull) }
            switch geometry["type"] as? String {
            case "LineString":
                guard let line = coordinates as? [[Double]] else { return viaJSON(json) }
                var coords = line.map { CLLocationCoordinate2D(latitude: $0[1], longitude: $0[0]) }
                let polyline = MLNPolylineFeature(coordinates: &coords, count: UInt(coords.count))
                polyline.attributes = attributes
                shapes.append(polyline)
            case "Polygon":
                guard let rings = coordinates as? [[[Double]]], let outer = rings.first, outer.count >= 3 else { return viaJSON(json) }
                var coords = outer.map { CLLocationCoordinate2D(latitude: $0[1], longitude: $0[0]) }
                let polygon = MLNPolygonFeature(coordinates: &coords, count: UInt(coords.count))
                // No attributes: a polygon with any attribute is never drawn on iOS (found 2026-10-29); labels use points.
                shapes.append(polygon)
            case "Point":
                guard let point = coordinates as? [Double], point.count >= 2 else { return viaJSON(json) }
                let marker = MLNPointFeature()
                marker.coordinate = CLLocationCoordinate2D(latitude: point[1], longitude: point[0])
                marker.attributes = attributes
                shapes.append(marker)
            default:
                return viaJSON(json)
            }
        }
        return MLNShapeCollectionFeature(shapes: shapes)
    }

    private static func viaJSON(_ json: [String: Any]) -> MLNShape? {
        guard let data = try? JSONSerialization.data(withJSONObject: json) else { return nil }
        return try? MLNShape(data: data, encoding: String.Encoding.utf8.rawValue)
    }
}

/// The train on the map (RouteMap.tsx marker): the operator's dot with a white rim, a chevron for the heading and a
/// halo that pulses outward; hollow when the position is only estimated.
/// The train on a trip's map: the same marker as Explore's (the flat disc in the operator's colour with the heading
/// cone; owner, 2026-10-29), with a pulsing halo while the position is live. An estimated position is drawn fainter.
final class TrainMarkerView: MLNAnnotationView {
    private let halo = CALayer()
    private let picture = CALayer()
    private var color = UIColor.systemYellow
    private var reduceMotion = UIAccessibility.isReduceMotionEnabled

    override init(reuseIdentifier: String?) {
        super.init(reuseIdentifier: reuseIdentifier)
        frame = CGRect(x: 0, y: 0, width: 36, height: 36)
        isUserInteractionEnabled = false
        halo.frame = CGRect(x: 10, y: 10, width: 16, height: 16)
        halo.cornerRadius = 8
        layer.addSublayer(halo)
        picture.frame = bounds
        picture.contentsGravity = .resizeAspect
        picture.contentsScale = UIScreen.main.scale
        layer.addSublayer(picture)
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    func configure(color: UIColor, estimated: Bool, bearing: Double?) {
        self.color = color
        halo.backgroundColor = color.withAlphaComponent(0.5).cgColor
        picture.contents = LiveMapImages.train(color: color, heading: bearing != nil).cgImage
        picture.opacity = estimated ? 0.7 : 1
        picture.setAffineTransform(CGAffineTransform(rotationAngle: CGFloat((bearing ?? 0) * .pi / 180)))
        halo.isHidden = estimated
        if halo.animation(forKey: "pulse") == nil && !reduceMotion {
            let scale = CABasicAnimation(keyPath: "transform.scale")
            scale.fromValue = 1
            scale.toValue = 2.4
            let fade = CABasicAnimation(keyPath: "opacity")
            fade.fromValue = 0.5
            fade.toValue = 0
            let group = CAAnimationGroup()
            group.animations = [scale, fade]
            group.duration = 1.8
            group.repeatCount = .infinity
            group.timingFunction = CAMediaTimingFunction(name: .easeOut)
            halo.add(group, forKey: "pulse")
        }
    }
}
