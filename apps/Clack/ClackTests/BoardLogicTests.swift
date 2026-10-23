//
//  BoardLogicTests.swift
//  ClackTests
//

import Foundation
import Testing
@testable import Clack

struct BoardLogicTests {
    private let now = 1_800_000_000_000.0

    private func row(_ id: String, advertised: Double, estimated: Double? = nil, actual: Double? = nil, canceled: Bool = false, product: String = "regional", op: String? = "sj", change: BoardRow.PlatformChange? = nil) -> BoardRow {
        BoardRow(id: id, trainNumber: "1", advertised: advertised, estimated: estimated, actual: actual, done: false, delayMin: nil, platform: "3", platformChange: change, canceled: canceled, deviations: [], endpoints: [], via: [], operatorId: op, productName: nil, product: product, trainType: nil, trip: nil)
    }

    @Test func hidesRowsMoreThanTenMinutesGoneAndOnesBeyondTheWindow() {
        let rows = [
            row("gone", advertised: now - 11 * 60_000), row("just", advertised: now - 9 * 60_000),
            row("soon", advertised: now + 60_000), row("far", advertised: now + 4 * 3_600_000),
        ]
        let shown = BoardLogic.visible(rows, now: now, filter: .init()).map(\.id)
        #expect(shown == ["just", "soon"])
    }

    @Test func aDelayedTrainStaysUntilItsExpectedTimePasses() {
        let late = row("late", advertised: now - 30 * 60_000, estimated: now + 5 * 60_000)
        #expect(BoardLogic.visible([late], now: now, filter: .init()).count == 1)
    }

    @Test func showEarlierKeepsPastRows() {
        var filter = BoardLogic.Filter()
        filter.showEarlier = true
        #expect(BoardLogic.visible([row("gone", advertised: now - 2 * 3_600_000)], now: now, filter: filter).count == 1)
    }

    @Test func cancelledRowsGoByTheirAdvertisedTime() {
        let rows = [row("old", advertised: now - 20 * 60_000, canceled: true), row("new", advertised: now + 60_000, canceled: true)]
        #expect(BoardLogic.visible(rows, now: now, filter: .init()).map(\.id) == ["new"])
    }

    @Test func filtersByCommuterOperatorAndProduct() {
        let rows = [row("a", advertised: now, product: "commuter"), row("b", advertised: now, op: "mtr"), row("c", advertised: now, product: "night")]
        var filter = BoardLogic.Filter()
        filter.commuter = false
        #expect(BoardLogic.visible(rows, now: now, filter: filter).map(\.id) == ["b", "c"])
        filter.operators = ["mtr"]
        #expect(BoardLogic.visible(rows, now: now, filter: filter).map(\.id) == ["b"])
        filter.operators = []
        filter.products = ["night"]
        #expect(BoardLogic.visible(rows, now: now, filter: filter).map(\.id) == ["c"])
    }

    @Test func aPlatformChangeShowsForFifteenMinutesOrWhenItsTimeIsUnknown() {
        #expect(BoardLogic.platformChanged(row("a", advertised: now, change: .init(from: "2", at: now - 5 * 60_000)), now: now))
        #expect(!BoardLogic.platformChanged(row("a", advertised: now, change: .init(from: "2", at: now - 20 * 60_000)), now: now))
        #expect(BoardLogic.platformChanged(row("a", advertised: now, change: .init(from: nil, at: nil)), now: now))
        #expect(!BoardLogic.platformChanged(row("a", advertised: now), now: now))
    }

    @Test func widenGoesOneHourToThreeToDay() {
        #expect(BoardLogic.Window.hour.wider == .threeHours)
        #expect(BoardLogic.Window.threeHours.wider == .day)
        #expect(BoardLogic.Window.day.wider == nil)
    }

    @Test func aPageIsTheFirstTwentyInTimeOrderWithinReachAndSaysIfThereAreMore() {
        let hour = 3_600_000.0
        // 30 departures, one every 20 minutes from now (the last one 9 h 40 min away).
        let rows = (0..<30).map { row("r\($0)", advertised: now + Double($0) * hour / 3) }
        var filter = BoardLogic.Filter()
        filter.window = .day
        let first = BoardLogic.page(rows, now: now, filter: filter, limit: 20, reach: 24 * hour)
        #expect(first.shown.count == 20 && first.more)
        #expect(first.shown.map(\.id) == (0..<20).map { "r\($0)" })
        let all = BoardLogic.page(rows, now: now, filter: filter, limit: 40, reach: 24 * hour)
        #expect(all.shown.count == 30 && !all.more)
        // Nothing past the reach: with 5 hours, the first 16 (0 to 5 h, the last exactly on the limit).
        let near = BoardLogic.page(rows, now: now, filter: filter, limit: 40, reach: 5 * hour)
        #expect(near.shown.count == 16 && !near.more)
    }

    @Test func aPageDropsRepeatsFromTheLiveBoardAndTheLaterFetch() {
        var filter = BoardLogic.Filter()
        filter.window = .day
        let a = row("same", advertised: now + 60_000)
        let page = BoardLogic.page([a, a, row("other", advertised: now + 120_000)], now: now, filter: filter, limit: 20, reach: 24 * 3_600_000)
        #expect(page.shown.map(\.id) == ["same", "other"])
    }
}
