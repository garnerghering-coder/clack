//
//  MapLibreSupport.swift
//  Clack
//

import ClackCore
import MapLibre
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

    /// Sets a GeoJSON source's data.
    func setShape(_ json: [String: Any], source id: String) {
        guard let source = style?.source(withIdentifier: id) as? MLNShapeSource,
              let data = try? JSONSerialization.data(withJSONObject: json),
              let shape = try? MLNShape(data: data, encoding: String.Encoding.utf8.rawValue) else { return }
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

    override func layoutSubviews() {
        super.layoutSubviews()
        guard bounds.width > 0, bounds.height > 0, bounds.size != laidOutSize else { return }
        laidOutSize = bounds.size
        if let wantedFit, !moved {
            fit(wantedFit.points, padding: wantedFit.padding, maxZoom: wantedFit.maxZoom, animated: false)
        }
    }
}

/// The train on the map (RouteMap.tsx marker): the operator's dot with a white rim, a chevron for the heading and a
/// halo that pulses outward; hollow when the position is only estimated.
final class TrainMarkerView: MLNAnnotationView {
    private let halo = CALayer()
    private let dot = CALayer()
    private let chevron = CAShapeLayer()
    private var color = UIColor.systemYellow
    private var estimated = false
    private var reduceMotion = UIAccessibility.isReduceMotionEnabled

    override init(reuseIdentifier: String?) {
        super.init(reuseIdentifier: reuseIdentifier)
        frame = CGRect(x: 0, y: 0, width: 14, height: 14)
        isUserInteractionEnabled = false
        for layer in [halo, dot] {
            layer.frame = bounds
            layer.cornerRadius = 7
            self.layer.addSublayer(layer)
        }
        chevron.frame = bounds
        layer.addSublayer(chevron)
        // A 10 wide, 7 tall triangle centred 17 above the dot, turned about the dot's centre.
        let path = UIBezierPath()
        path.move(to: CGPoint(x: 7, y: -10))
        path.addLine(to: CGPoint(x: 2, y: -3))
        path.addLine(to: CGPoint(x: 12, y: -3))
        path.close()
        chevron.path = path.cgPath
        chevron.fillColor = UIColor.white.cgColor
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    func configure(color: UIColor, estimated: Bool, bearing: Double?) {
        self.color = color
        self.estimated = estimated
        halo.backgroundColor = color.withAlphaComponent(0.5).cgColor
        // Estimated: a hollow dot with a 3 pt ring in the operator colour; live: a filled dot with a white rim.
        dot.backgroundColor = (estimated ? UIColor.black : color).cgColor
        dot.borderColor = (estimated ? color : UIColor.white).cgColor
        dot.borderWidth = estimated ? 3 : 2
        chevron.isHidden = bearing == nil
        chevron.setAffineTransform(CGAffineTransform(rotationAngle: CGFloat((bearing ?? 0) * .pi / 180)))
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
