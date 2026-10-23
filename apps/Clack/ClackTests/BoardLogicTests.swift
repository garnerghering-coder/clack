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
}
