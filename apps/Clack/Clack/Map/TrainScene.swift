//
//  TrainScene.swift
//  Clack
//

import ClackCore
import ClackDesign
import RealityKit
import SwiftUI
import UIKit

/// The simple 3D trains (BUILDOUT F3): five generic designs built from boxes, coloured from the operator's brand
/// colour, with as many cars as the data gives (`TrainKit`). Nothing here claims to be a particular model: an unknown
/// type is drawn unpainted. Units are metres; a car's origin is its middle at rail level; forward is -Z.
enum TrainScene {
    struct Colours {
        var body: UIColor
        var band = UIColor(white: 0.12, alpha: 1)
        var roof = UIColor(white: 0.75, alpha: 1)
        var loco: UIColor

        /// The operator's brand colour for the body; grey when unknown (an unpainted train).
        static func forOperator(_ brandColor: String?, dark: Bool) -> Colours {
            let body = UIColor(operatorColor(brandColor, scheme: dark ? .dark : .light))
            return Colours(body: brandColor == nil ? UIColor(white: 0.82, alpha: 1) : body, loco: brandColor == nil ? UIColor(white: 0.6, alpha: 1) : body.darker(0.25))
        }
    }

    /// One car of a design, as an entity whose children are the body, roof and window band.
    static func car(_ template: TrainKit.Template, index: Int, count: Int, colours: Colours, length: Double) -> Entity {
        let car = Entity()
        let l = Float(length)
        let width: Float = 3.0
        let isLoco = template == .locoCoaches && index == 0
        let height: Float = template == .doubleDeck ? 4.6 : (isLoco ? 4.2 : 3.9)
        let floor: Float = 1.0
        func box(_ w: Float, _ h: Float, _ d: Float, _ colour: UIColor, y: Float, z: Float = 0, cornerRadius: Float = 0.15) -> ModelEntity {
            let m = ModelEntity(mesh: .generateBox(width: w, height: h, depth: d, cornerRadius: cornerRadius), materials: [SimpleMaterial(color: colour, roughness: 0.6, isMetallic: false)])
            m.position = [0, y, z]
            return m
        }
        let bodyLength: Float = isLoco ? min(l, 19) : l
        // Body: from the floor to just under the roof.
        car.addChild(box(width, height - floor - 0.3, bodyLength, isLoco ? colours.loco : colours.body, y: floor + (height - floor - 0.3) / 2))
        // Roof: a little narrower, slightly rounded.
        car.addChild(box(width - 0.4, 0.3, bodyLength - 0.3, colours.roof, y: height - 0.15, cornerRadius: 0.14))
        // Window band on both sides (one thin box slightly wider than the body).
        if !isLoco {
            let bandY = template == .doubleDeck ? floor + 2.0 : floor + 1.6
            car.addChild(box(width + 0.04, 0.8, bodyLength - 1.6, colours.band, y: bandY, cornerRadius: 0.05))
            if template == .doubleDeck { car.addChild(box(width + 0.04, 0.7, bodyLength - 1.6, colours.band, y: floor + 0.7, cornerRadius: 0.05)) }
        }
        // Underframe and bogies.
        car.addChild(box(width - 0.6, 0.5, bodyLength - 0.6, UIColor(white: 0.2, alpha: 1), y: floor - 0.25, cornerRadius: 0.05))
        for z in [-(bodyLength / 2 - 3.0), bodyLength / 2 - 3.0] {
            car.addChild(box(width - 0.3, 0.6, 2.6, UIColor(white: 0.15, alpha: 1), y: 0.5, z: z, cornerRadius: 0.1))
        }
        // The cab ends: a sloped nose on the front of a unit (and the back of the last car), long on a high-speed set.
        let noseLength: Float = template == .highSpeed ? 4.0 : (template == .multipleUnit ? 1.2 : 0.6)
        if template != .locoCoaches || isLoco {
            if index == 0 { car.addChild(nose(width: width - 0.2, height: height - floor - 0.6, length: noseLength, colour: isLoco ? colours.loco : colours.body, y: floor + 0.2, z: -bodyLength / 2, forward: true)) }
            if index == count - 1 && template != .locoCoaches { car.addChild(nose(width: width - 0.2, height: height - floor - 0.6, length: noseLength, colour: colours.body, y: floor + 0.2, z: bodyLength / 2, forward: false)) }
        }
        return car
    }

    /// A wedge for the cab: a box scaled thin at the far end gives the slope without custom meshes.
    private static func nose(width: Float, height: Float, length: Float, colour: UIColor, y: Float, z: Float, forward: Bool) -> ModelEntity {
        let m = ModelEntity(mesh: .generateBox(width: width, height: height, depth: length, cornerRadius: 0.3), materials: [SimpleMaterial(color: colour, roughness: 0.6, isMetallic: false)])
        m.position = [0, y + height / 2, z + (forward ? -length / 2 : length / 2)]
        // Tilt the wedge so its far end is lower: a small pitch around the X axis.
        let tilt: Float = forward ? 0.35 : -0.35
        m.orientation = simd_quatf(angle: tilt, axis: [1, 0, 0])
        return m
    }

    /// A whole train: `poses` from `TrainKit.carPoses`, placed relative to `origin` (the point the scene is centred
    /// on, in metres east/north) and turned to `headingDeg`.
    static func train(template: TrainKit.Template, poses: [TrainKit.CarPose], colours: Colours, carLength: Double, origin: LatLon, viewHeadingDeg: Double) -> Entity {
        let root = Entity()
        for (i, pose) in poses.enumerated() {
            let c = car(template, index: i, count: poses.count, colours: colours, length: carLength)
            let (east, north) = TrainScene.metres(from: origin, to: pose.center)
            // Scene axes: X east, Z south (RealityKit's -Z is "forward" = north before the view turns).
            let yaw = Float((viewHeadingDeg - pose.headingDeg) * .pi / 180)
            let viewRad = viewHeadingDeg * .pi / 180
            // Rotate the world so the view heading points to -Z.
            let x = Float(east * cos(viewRad) - north * sin(viewRad))
            let z = Float(-(east * sin(viewRad) + north * cos(viewRad)))
            c.position = [x, 0, z]
            c.orientation = simd_quatf(angle: yaw, axis: [0, 1, 0])
            root.addChild(c)
        }
        return root
    }

    static func metres(from a: LatLon, to b: LatLon) -> (east: Double, north: Double) {
        let k = 111_320.0
        return ((b.lon - a.lon) * k * cos(a.lat * .pi / 180), (b.lat - a.lat) * k)
    }
}

private extension UIColor {
    func darker(_ amount: CGFloat) -> UIColor {
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        guard getHue(&h, saturation: &s, brightness: &b, alpha: &a) else { return self }
        return UIColor(hue: h, saturation: s, brightness: max(0, b * (1 - amount)), alpha: a)
    }
}
