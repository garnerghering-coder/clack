//
//  RouteTests.swift
//  ClackTests
//
//  Every `clack://` form the app opens (DeepLink.parse), and that the URLs widgets and the trip card build come back.
//

import Foundation
import Testing
@testable import ClackCore

private func link(_ string: String) -> DeepLink? {
    URL(string: string).flatMap(DeepLink.parse)
}

struct RouteTests {
    @Test func aTripOpensOnTrips() {
        #expect(link("clack://trip/leg-123") == .trip("leg-123"))
        #expect(link("clack://trip/leg-123")?.tab == .trips)
        #expect(link("clack:///trip/leg-123") == .trip("leg-123"))
        #expect(link("CLACK://TRIP/leg-123") == .trip("leg-123"))
        #expect(link("clack://trip") == nil)
        #expect(link("clack://trip/") == nil)
    }

    @Test func aJourneyOpensOnTrips() {
        #expect(link("clack://journey/j-42") == .journey("j-42"))
        #expect(link("clack://journey/j-42")?.tab == .trips)
        #expect(link("clack://journey") == nil)
    }

    @Test func aBoardOpensOnExplore() {
        #expect(link("clack://board/740000001") == .board(stationId: "740000001", arrivals: false))
        #expect(link("clack://board/740000001?arrivals=1") == .board(stationId: "740000001", arrivals: true))
        #expect(link("clack://board/740000001?arrivals=true") == .board(stationId: "740000001", arrivals: true))
        #expect(link("clack://board/740000001?arrivals=0") == .board(stationId: "740000001", arrivals: false))
        #expect(link("clack://board/740000001")?.tab == .explore)
        #expect(link("clack://board") == nil)
    }

    @Test func aTrainOpensOnExploreAndNeedsItsDay() {
        #expect(link("clack://explore?train=537&date=2026-10-24&key=abc") == .train(number: "537", date: "2026-10-24", key: "abc"))
        #expect(link("clack://explore?train=537&date=2026-10-24") == .train(number: "537", date: "2026-10-24", key: nil))
        #expect(link("clack://explore?train=537&date=2026-10-24")?.tab == .explore)
        // Without a number and a well-formed day there is no train to show, only the tab.
        #expect(link("clack://explore?train=537") == .tab(.explore))
        #expect(link("clack://explore?train=537&date=tomorrow") == .tab(.explore))
        #expect(link("clack://explore?date=2026-10-24") == .tab(.explore))
        #expect(link("clack://explore") == .tab(.explore))
    }

    @Test func theTabsOpenAtTheirRoot() {
        #expect(link("clack://tab/trips") == .tab(.trips))
        #expect(link("clack://tab/explore") == .tab(.explore))
        #expect(link("clack://tab/passport") == .tab(.passport))
        #expect(link("clack://tab/Passport") == .tab(.passport))
        #expect(link("clack://tab/settings") == nil)
        #expect(link("clack://tab") == nil)
        #expect(link("clack://trips") == .tab(.trips))
        #expect(link("clack://passport") == .tab(.passport))
        #expect(link("clack://passport")?.tab == .passport)
    }

    @Test func addOpensTheSheetAtConfirmWithATrip() {
        #expect(link("clack://add?trip=K1&date=2026-10-24&from=2&to=9") == .add(AddTrainLink(tripKey: "K1", date: "2026-10-24", fromSeq: 2, toSeq: 9)))
        #expect(link("clack://add?trip=K1&date=2026-10-24&from=&to=") == .add(AddTrainLink(tripKey: "K1", date: "2026-10-24")))
        #expect(link("clack://add?trip=K1&date=2026-10-24&replace=leg-9") == .add(AddTrainLink(tripKey: "K1", date: "2026-10-24", replaceLegId: "leg-9")))
        #expect(link("clack://add?trip=K1&date=2026-10-24&from=x") == .add(AddTrainLink(tripKey: "K1", date: "2026-10-24")))
        #expect(link("clack://add") == .add(nil))
        #expect(link("clack://add?trip=K1") == .add(nil))
        #expect(link("clack://add")?.tab == nil)
    }

    @Test func anArrivalOpensTheCelebration() {
        #expect(link("clack://arrival/leg-7") == .arrival(legId: "leg-7", journeyId: nil))
        #expect(link("clack://arrival/leg-7?journey=j-3") == .arrival(legId: "leg-7", journeyId: "j-3"))
        #expect(link("clack://arrival/leg-7")?.tab == nil)
        #expect(link("clack://arrival") == nil)
    }

    @Test func anythingElseOpensNothing() {
        #expect(link("https://getclack.app/trip/leg-1") == nil)
        #expect(link("clack://") == nil)
        #expect(link("clack://settings") == nil)
        #expect(link("file:///tmp/ticket.pkpass") == nil)
    }

    @Test func anAlertOpensWhatItIsAbout() {
        #expect(DeepLink.forAlert(legId: "l1", journeyId: "j1", kind: "arrival") == .arrival(legId: "l1", journeyId: "j1"))
        #expect(DeepLink.forAlert(legId: "l1", journeyId: nil, kind: "arrival") == .arrival(legId: "l1", journeyId: nil))
        #expect(DeepLink.forAlert(legId: "l1", journeyId: "j1", kind: "change") == .journey("j1"))
        #expect(DeepLink.forAlert(legId: "l1", journeyId: nil, kind: "change") == .trip("l1"))
        #expect(DeepLink.forAlert(legId: "l1", journeyId: "j1", kind: "delay") == .trip("l1"))
        #expect(DeepLink.forAlert(legId: "l1", journeyId: "j1", kind: "") == .trip("l1"))
    }

    @Test func theBuiltURLsReadBack() {
        let all: [DeepLink] = [
            .trip("leg-1"), .journey("j-1"), .board(stationId: "740000001", arrivals: false),
            .board(stationId: "740000001", arrivals: true), .train(number: "537", date: "2026-10-24", key: "k 1&2"),
            .train(number: "537", date: "2026-10-24", key: nil), .tab(.trips), .tab(.explore), .tab(.passport),
            .add(nil), .add(AddTrainLink(tripKey: "K1", date: "2026-10-24", fromSeq: 1, toSeq: 4, replaceLegId: "leg-2")),
            .arrival(legId: "leg-3", journeyId: "j-3"), .arrival(legId: "leg-3", journeyId: nil),
        ]
        for item in all { #expect(DeepLink.parse(item.url) == item, "\(item.url)") }
        #expect(DeepLink.trip("leg-1").url.absoluteString == "clack://trip/leg-1")
        #expect(DeepLink.tab(.passport).url.absoluteString == "clack://tab/passport")
        #expect(DeepLink.board(stationId: "740000001", arrivals: true).url.absoluteString == "clack://board/740000001?arrivals=1")
    }
}
