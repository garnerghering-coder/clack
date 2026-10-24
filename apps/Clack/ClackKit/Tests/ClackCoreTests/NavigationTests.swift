//
//  NavigationTests.swift
//  ClackTests
//

import Foundation
import Testing
@testable import ClackCore

struct NavigationTests {
    @Test func aTrainOpensInPlaceExceptOnExplore() {
        #expect(Navigation.trainOpening(tab: .explore) == .focusOnMap)
        #expect(Navigation.trainOpening(tab: .trips) == .sheet)
        #expect(Navigation.trainOpening(tab: .passport) == .sheet)
    }

    @Test func theBackButtonNamesTheScreenUnderneath() {
        // Right on the tab's first screen: the tab's name, whichever tab it is (no "Trips" on Explore's board).
        #expect(Navigation.backLabelKey(below: nil, tab: .trips) == "nav.trips")
        #expect(Navigation.backLabelKey(below: nil, tab: .explore) == "nav.explore")
        #expect(Navigation.backLabelKey(below: nil, tab: .passport) == "nav.passport")
        #expect(Navigation.backLabelKey(below: .trip, tab: .trips) == "nav.trip")
        #expect(Navigation.backLabelKey(below: .board, tab: .explore) == "board.departures")
        #expect(Navigation.backLabelKey(below: .settings, tab: .passport) == "settings.title")
        #expect(Navigation.backLabelKey(below: .stationMap, tab: .explore) == "common.back")
    }

    @Test func theScreenUnderneathTheTopOne() {
        #expect(Navigation.below([Int]()) == nil)
        #expect(Navigation.below([1]) == nil)
        #expect(Navigation.below([1, 2, 3]) == 2)
    }
}
