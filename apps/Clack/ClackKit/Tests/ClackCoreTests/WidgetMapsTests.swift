//
//  WidgetMapsTests.swift
//  ClackCoreTests
//

import Testing
@testable import ClackCore

struct WidgetMapsTests {
    private func year(_ routes: [[[Double]]], _ y: Int = 2026) -> WidgetSnapshot.YearBits {
        .init(year: y, km: 1, trains: 1, topRouteCount: 0, busiestMonthCount: 0, routes: routes)
    }

    @Test func theSameRoutesAlwaysGiveTheSameKeyAndOtherRoutesAnotherOne() {
        let a = year([[[59.33, 18.06], [57.7, 11.97]]])
        #expect(WidgetMaps.key(a) == WidgetMaps.key(year([[[59.33, 18.06], [57.7, 11.97]]])))
        #expect(WidgetMaps.key(a) != WidgetMaps.key(year([[[59.33, 18.06], [55.6, 13.0]]])))
        #expect(WidgetMaps.key(a) != WidgetMaps.key(year([[[59.33, 18.06], [57.7, 11.97]]], 2025)))
    }

    @Test func aPictureIsNamedAfterItsRoutesAndLook() {
        #expect(WidgetMaps.fileName(key: "ab", dark: true) == "year-map-ab-dark.png")
        #expect(WidgetMaps.fileName(key: "ab", dark: false) == "year-map-ab-light.png")
    }
}
