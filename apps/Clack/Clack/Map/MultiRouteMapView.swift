//
//  MultiRouteMapView.swift
//  Clack
//

import ClackCore
import MapLibre
import ClackDesign
import SwiftUI

nonisolated struct MultiRoute: Hashable, Sendable {
    var color: String
    /// An encoded polyline.
    var geometry: String?
    /// Fallback when there's no routed geometry: just the end stations.
    var stops: [LatLon]

    /// A cheap stand-in for "is this the same route": colour and the size of the geometry (O(1) for a native string),
    /// so the map's identity doesn't cost a pass over every polyline on each render.
    var identity: Int {
        var h = Hasher()
        h.combine(color)
        h.combine(geometry?.utf8.count ?? -1)
        h.combine(stops.count)
        return h.finalize()
    }
}

extension MultiRoute {
    /// The map is rebuilt when this changes: the theme, the basemap, or the set of routes (year and commuter filters).
    static func mapIdentity(_ routes: [MultiRoute], stations: [MultiStation], dark: Bool, basemap: Bool, railNetwork: Bool) -> Int {
        var h = Hasher()
        h.combine(dark)
        h.combine(basemap)
        h.combine(railNetwork)
        h.combine(stations.count)
        for route in routes { h.combine(route.identity) }
        return h.finalize()
    }
}

nonisolated struct MultiStation: Hashable, Sendable {
    var lat: Double
    var lon: Double
    var name: String
    var count: Int
}

/// Every ridden route on one map (Passport, journey; MultiRouteMap.tsx): each line in its operator colour, with a
/// soft glow so lines you've ridden many times build up brighter, and station dots that grow with the visits.
struct MultiRouteMapView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.colorScheme) private var scheme
    let routes: [MultiRoute]
    let stations: [MultiStation]
    var railNetwork = false
    var label: String?
    @State private var basemap: Bool?

    var body: some View {
        ZStack {
            Ink.mapBg
            if let basemap, hasShape {
                MultiRouteRepresentable(
                    routes: routes, stations: stations, railNetwork: railNetwork, withBasemap: basemap, dark: scheme == .dark
                )
                // Rebuilt when the set of routes changes (year and commuter filters) or the theme does.
                .id(MultiRoute.mapIdentity(routes, stations: stations, dark: scheme == .dark, basemap: basemap, railNetwork: railNetwork))
            }
            VStack {
                Spacer()
                HStack {
                    Text("© OpenStreetMap contributors · Protomaps")
                        .clack(.mapAttribution).foregroundStyle(Ink.text3)
                        .padding(.leading, 8).padding(.bottom, 6).allowsHitTesting(false)
                    Spacer()
                }
            }
        }
        .clipped()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label ?? "")
        .task { basemap = await app.mapHasBasemap() }
    }

    /// Something to draw (no polyline is decoded here: the map decodes them once, when its style has loaded).
    private var hasShape: Bool { routes.contains { $0.geometry != nil || !$0.stops.isEmpty } }
}

private struct MultiRouteRepresentable: UIViewRepresentable {
    let routes: [MultiRoute]
    let stations: [MultiStation]
    let railNetwork: Bool
    let withBasemap: Bool
    let dark: Bool

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> MLNMapView {
        let style = MapStyle.style(base: Config.apiBase, withBasemap: withBasemap, dark: dark, railNetwork: railNetwork, kind: .multiRoute)
        let url = (try? MapStyle.write(style)) ?? URL(fileURLWithPath: "/dev/null")
        let map = ClackMapView(frame: .zero, styleURL: url)
        map.applyClackDefaults()
        map.delegate = context.coordinator
        map.setCenter(CLLocationCoordinate2D(latitude: 62, longitude: 15), zoomLevel: 4, animated: false)
        return map
    }

    func updateUIView(_ map: MLNMapView, context: Context) {}

    @MainActor
    final class Coordinator: NSObject, MLNMapViewDelegate {
        let parent: MultiRouteRepresentable

        init(_ parent: MultiRouteRepresentable) { self.parent = parent }

        func mapView(_ mapView: MLNMapView, didFinishLoading style: MLNStyle) {
            let p = parent
            var all: [LatLon] = []
            let features: [[String: Any]] = p.routes.map { route in
                let points = route.geometry.map(Polyline.decode) ?? route.stops
                all += points
                return [
                    "type": "Feature", "properties": ["color": route.color],
                    "geometry": ["type": "LineString", "coordinates": points.map { [$0.lon, $0.lat] }],
                ]
            }
            mapView.setShape(["type": "FeatureCollection", "features": features], source: "routes")
            let stationFeatures: [[String: Any]] = p.stations.map { s in
                [
                    "type": "Feature", "properties": ["name": s.name, "count": s.count],
                    "geometry": ["type": "Point", "coordinates": [s.lon, s.lat]],
                ]
            }
            mapView.setShape(["type": "FeatureCollection", "features": stationFeatures], source: "stations")
            mapView.fit(all, padding: UIEdgeInsets(top: 36, left: 36, bottom: 36, right: 36), maxZoom: 10, animated: false)
        }
    }
}
