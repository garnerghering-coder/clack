//
//  MultiRouteKeyTests.swift
//  ClackTests
//

import ClackCore
import Testing
@testable import Clack

struct MultiRouteKeyTests {
    private let a = MultiRoute(color: "#112233", geometry: "abcdef", stops: [])
    private let b = MultiRoute(color: "#445566", geometry: nil, stops: [LatLon(59, 18), LatLon(58, 16)])

    private func key(_ routes: [MultiRoute], dark: Bool = false) -> Int {
        MultiRoute.mapIdentity(routes, stations: [], dark: dark, basemap: true, railNetwork: false)
    }

    @Test func sameRoutesGiveTheSameKey() {
        #expect(key([a, b]) == key([a, b]))
    }

    @Test func aDifferentSetOrThemeChangesTheKey() {
        #expect(key([a, b]) != key([a]))
        #expect(key([a, b]) != key([a, b], dark: true))
        #expect(key([a]) != key([MultiRoute(color: a.color, geometry: "abcdefgh", stops: [])]))
    }
}
