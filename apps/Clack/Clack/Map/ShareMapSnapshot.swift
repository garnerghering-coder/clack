//
//  ShareMapSnapshot.swift
//  Clack
//

import MapLibre
import UIKit

/// A real map for a share card (share/mapSnapshot.ts): MapLibre's snapshotter draws the dark basemap and rail network
/// off screen, the routes go on top in signal yellow with a soft glow. Nil when the map can't load; the card then draws
/// the lines alone.
struct ShareMapSnapshot {
    let image: UIImage
    /// Where each requested point landed, in the snapshot's points.
    let points: [CGPoint]
    let size: CGSize
}

@MainActor
enum ShareMapSnapshotter {
    private static let accent = UIColor(red: 248 / 255, green: 214 / 255, blue: 74 / 255, alpha: 1)

    /// `lines` are the routes along the tracks; `ends` the stops to dot; `points` where labels will go.
    static func make(lines: [[LatLon]], ends: [LatLon], points: [LatLon], size: CGSize, base: URL, withBasemap: Bool) async -> ShareMapSnapshot? {
        let all = lines.filter { $0.count > 1 }.flatMap { $0 }
        guard all.count >= 2, let box = MapGeometry.bounds(all) else { return nil }
        let style = MapStyle.style(base: base, withBasemap: withBasemap, dark: true, railNetwork: true, kind: .multiRoute)
        guard let url = try? MapStyle.write(style) else { return nil }
        // MapLibre stamps its logo on the bottom of a snapshot, so the picture is taken with a band top and bottom that is
        // cropped off again (the card carries no logo; the attribution is on the web's cards too).
        let band: CGFloat = 44
        let frame = CGSize(width: size.width, height: size.height + 2 * band)
        // Room around the routes (the web's padding 56 / 64), and no closer than zoom 10.
        let padX = 64.0 * 2 / frame.width, padY = (56.0 * 2 + 2 * Double(band)) / Double(frame.height)
        let lonSpan = max((box.east - box.west) / (1 - padX), 0.33)
        let latSpan = max((box.north - box.south) / (1 - padY), 0.17)
        let centre = CLLocationCoordinate2D(latitude: (box.north + box.south) / 2, longitude: (box.east + box.west) / 2)
        let options = MLNMapSnapshotOptions(styleURL: url, camera: MLNMapCamera(), size: frame)
        options.coordinateBounds = MLNCoordinateBounds(
            sw: CLLocationCoordinate2D(latitude: centre.latitude - latSpan / 2, longitude: centre.longitude - lonSpan / 2),
            ne: CLLocationCoordinate2D(latitude: centre.latitude + latSpan / 2, longitude: centre.longitude + lonSpan / 2)
        )
        options.scale = 2
        let snapshotter = MLNMapSnapshotter(options: options)
        return await withCheckedContinuation { continuation in
            var finished = false
            func finish(_ result: ShareMapSnapshot?) {
                guard !finished else { return }
                finished = true
                snapshotter.cancel()
                continuation.resume(returning: result)
            }
            // A slow or missing map isn't worth holding the card for.
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(10))
                finish(nil)
            }
            snapshotter.start(overlayHandler: { overlay in
                let g = overlay.context
                g.setLineCap(.round)
                g.setLineJoin(.round)
                func path(_ line: [LatLon]) {
                    g.beginPath()
                    for (i, p) in line.enumerated() {
                        let pt = overlay.point(for: CLLocationCoordinate2D(latitude: p.lat, longitude: p.lon))
                        i == 0 ? g.move(to: pt) : g.addLine(to: pt)
                    }
                }
                for line in lines where line.count > 1 {
                    path(line)
                    g.setStrokeColor(accent.withAlphaComponent(0.3).cgColor)
                    g.setLineWidth(12)
                    g.strokePath()
                }
                for line in lines where line.count > 1 {
                    path(line)
                    g.setStrokeColor(accent.cgColor)
                    g.setLineWidth(4)
                    g.strokePath()
                }
                for end in ends {
                    let c = overlay.point(for: CLLocationCoordinate2D(latitude: end.lat, longitude: end.lon))
                    let rect = CGRect(x: c.x - 5, y: c.y - 5, width: 10, height: 10)
                    g.setFillColor(UIColor(red: 10 / 255, green: 10 / 255, blue: 10 / 255, alpha: 1).cgColor)
                    g.fillEllipse(in: rect)
                    g.setStrokeColor(UIColor.white.cgColor)
                    g.setLineWidth(2.5)
                    g.strokeEllipse(in: rect)
                }
            }, completionHandler: { snapshot, error in
                guard let snapshot, error == nil else { finish(nil); return }
                let located = points.map { p -> CGPoint in
                    let at = snapshot.point(for: CLLocationCoordinate2D(latitude: p.lat, longitude: p.lon))
                    return CGPoint(x: at.x, y: at.y - band)
                }
                let format = UIGraphicsImageRendererFormat()
                format.scale = 2
                let cropped = UIGraphicsImageRenderer(size: size, format: format).image { _ in
                    snapshot.image.draw(at: CGPoint(x: 0, y: -band))
                }
                finish(ShareMapSnapshot(image: cropped, points: located, size: size))
            })
        }
    }
}
