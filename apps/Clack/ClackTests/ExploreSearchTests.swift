//
//  ExploreSearchTests.swift
//  ClackTests
//

import Testing
@testable import Clack

/// Explore's search state: picking a result clears the text, and that must not open the search again over the sheet
/// the pick opened (it did, and the station list covered the station's sheet).
@MainActor
struct ExploreSearchTests {
    @Test func typingOpensTheSearchAndClosesTheFiltersAndLegend() {
        let model = ExploreModel()
        model.showFilters = true
        model.legend = true
        model.query = "Stock"
        model.queryChanged()
        #expect(model.searching)
        #expect(!model.showFilters)
        #expect(!model.legend)
    }

    @Test func clearingTheTextDoesNotOpenTheSearch() {
        let model = ExploreModel()
        model.query = ""
        model.queryChanged()
        #expect(!model.searching)
        model.query = "   "
        model.queryChanged()
        #expect(!model.searching)
    }

    @Test func clearingTheTextKeepsAnOpenSearchOpen() {
        let model = ExploreModel()
        model.startSearch()
        model.query = ""
        model.queryChanged()
        #expect(model.searching)
    }

    @Test func aPickEndsTheSearchForGood() {
        let model = ExploreModel()
        model.query = "529"
        model.queryChanged()
        model.endSearch()
        // The field's onChange runs after the pick cleared the text.
        model.queryChanged()
        #expect(!model.searching)
        #expect(model.query.isEmpty)
        #expect(model.stationHits.isEmpty)
    }
}
