//
//  PassportLogicTests.swift
//  ClackTests
//

import Testing
@testable import ClackCore

struct PassportLogicTests {
    @Test func theStageFollowsTheNumberOfJourneys() {
        #expect(PassportLogic.stage(journeys: 0) == .empty)
        #expect(PassportLogic.stage(journeys: 1) == .starting)
        #expect(PassportLogic.stage(journeys: 4) == .starting)
        #expect(PassportLogic.stage(journeys: 5) == .established)
        #expect(PassportLogic.stage(journeys: 200) == .established)
    }

    @Test func recordsWaitForTheThirdJourney() {
        #expect(!PassportLogic.showsRecords(journeys: 2))
        #expect(PassportLogic.showsRecords(journeys: 3))
    }

    @Test func tabsKeepTheirOrderAndLeaveOutEmptyCollections() {
        let all = PassportLogic.collectionTabs(operators: 3, countries: 2, stations: 40, kinds: 2, trainTypes: 5)
        #expect(all.map(\.tab) == [.operators, .countries, .stations, .kinds, .trainTypes])
        #expect(all.map(\.count) == [3, 2, 40, 2, 5])
        let noTypes = PassportLogic.collectionTabs(operators: 1, countries: 1, stations: 2, kinds: 1, trainTypes: 0)
        #expect(noTypes.map(\.tab) == [.operators, .countries, .stations, .kinds])
        #expect(PassportLogic.collectionTabs(operators: 0, countries: 0, stations: 0, kinds: 0, trainTypes: 0).isEmpty)
    }

    @Test func toGoIsWhatIsLeftRoundedUpAndNeverZero() {
        #expect(PassportLogic.toGo(value: 2, target: 5) == 3)
        #expect(PassportLogic.toGo(value: nil, target: 1) == 1)
        #expect(PassportLogic.toGo(value: 98.6, target: 100) == 2)
        #expect(PassportLogic.toGo(value: 100, target: 100) == 1)
    }
}
