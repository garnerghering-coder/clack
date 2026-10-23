//
//  OfflineMaps.swift
//  Clack
//

import Foundation
import MapLibre

/// Maps with no connection (owner, 2026-10-24): the tiles of maps you have looked at stay on the phone (a big cache), and the
/// map around each trip about to be ridden is downloaded while online, so routes and the train show underground or out of range.
/// The basemap tiles come from the Clack server; the packs store them in MapLibre's own database.
@MainActor
enum OfflineMaps {
    static let ambientBytes: UInt = 250 * 1024 * 1024
    private static let key = "clackLeg"

    static func configure() {
        MLNOfflineStorage.shared.setMaximumAmbientCacheSize(ambientBytes) { _ in }
    }

    /// The route's box, with about 10 km around it.
    static func bounds(of route: [LatLon]) -> MLNCoordinateBounds? {
        guard let first = route.first else { return nil }
        var south = first.lat, north = first.lat, west = first.lon, east = first.lon
        for p in route {
            south = min(south, p.lat); north = max(north, p.lat); west = min(west, p.lon); east = max(east, p.lon)
        }
        return MLNCoordinateBounds(
            sw: CLLocationCoordinate2D(latitude: south - 0.09, longitude: west - 0.16),
            ne: CLLocationCoordinate2D(latitude: north + 0.09, longitude: east + 0.16)
        )
    }

    private static func legId(_ pack: MLNOfflinePack) -> String? {
        (try? JSONSerialization.jsonObject(with: pack.context) as? [String: String])?[key]
    }

    /// Packs for these trips (those not saved yet are downloaded), and packs for trips no longer wanted are dropped.
    static func ensure(_ details: [LegDetail], keep: Set<String>) async {
        let storage = MLNOfflineStorage.shared
        let wanted = keep.union(details.map(\.leg.id))
        let have = Set((storage.packs ?? []).compactMap(legId))
        for pack in storage.packs ?? [] where legId(pack).map({ !wanted.contains($0) }) == true {
            await withCheckedContinuation { (c: CheckedContinuation<Void, Never>) in storage.removePack(pack) { _ in c.resume() } }
        }
        guard let styleURL = try? MapStyle.write(MapStyle.style(base: Config.apiBase, withBasemap: true, dark: true, railNetwork: true, kind: .route(color: "#F8D64A"))) else { return }
        for detail in details where !have.contains(detail.leg.id) {
            guard let box = bounds(of: detail.mapRoute().route) else { continue }
            // A long route would be a lot of tiles at street level: stop a zoom earlier.
            let wide = (box.ne.longitude - box.sw.longitude) > 6
            let region = MLNTilePyramidOfflineRegion(styleURL: styleURL, bounds: box, fromZoomLevel: 0, toZoomLevel: wide ? 9 : 10)
            guard let context = try? JSONSerialization.data(withJSONObject: [key: detail.leg.id]) else { continue }
            await withCheckedContinuation { (c: CheckedContinuation<Void, Never>) in
                storage.addPack(for: region, withContext: context) { pack, _ in
                    pack?.resume()
                    c.resume()
                }
            }
        }
    }

    /// How many trips' maps are saved.
    static var savedCount: Int { MLNOfflineStorage.shared.packs?.count ?? 0 }

    static func clear() async {
        let storage = MLNOfflineStorage.shared
        for pack in storage.packs ?? [] {
            await withCheckedContinuation { (c: CheckedContinuation<Void, Never>) in storage.removePack(pack) { _ in c.resume() } }
        }
    }
}
