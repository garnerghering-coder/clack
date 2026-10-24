//
//  ShapeTests.swift
//  ClackTests
//

import ClackCore
import MapLibre
import Testing
@testable import Clack

struct ShapeTests {
    @Test func linesBecomePolylineFeatures() throws {
        let json = MapGeometry.lines([[LatLon(59, 18), LatLon(58, 16)], [LatLon(1, 1)]])
        let collection = try #require(MLNShape.fromGeoJSON(json) as? MLNShapeCollectionFeature)
        #expect(collection.shapes.count == 1)
        let line = try #require(collection.shapes.first as? MLNPolylineFeature)
        #expect(line.pointCount == 2)
        #expect(line.coordinates[0].latitude == 59 && line.coordinates[0].longitude == 18)
    }

    @Test func pointsKeepTheirProperties() throws {
        let json: [String: Any] = [
            "type": "FeatureCollection",
            "features": [[
                "type": "Feature", "properties": ["name": "Lund", "count": 3],
                "geometry": ["type": "Point", "coordinates": [13.2, 55.7]],
            ] as [String: Any]],
        ]
        let collection = try #require(MLNShape.fromGeoJSON(json) as? MLNShapeCollectionFeature)
        let point = try #require(collection.shapes.first as? MLNPointFeature)
        #expect(point.attributes["name"] as? String == "Lund")
        #expect(point.attributes["count"] as? Int == 3)
        #expect(point.coordinate.latitude == 55.7)
    }

    @Test func emptyCollectionIsAShape() {
        #expect(MLNShape.fromGeoJSON(MapGeometry.lines([])) != nil)
    }
}
