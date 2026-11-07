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

    @Test func theLadderHasEveryLevelMarksTheEarnedOnesAndKeepsAnUnknownTarget() {
        let earned = Milestone(family: .journeys, target: 10, at: Instant(ms: 1), legId: "L", value: nil)
        let odd = Milestone(family: .kindsOfTrain, target: 6, at: Instant(ms: 2), legId: nil, value: nil)
        let next = Milestone(family: .journeys, target: 25, at: nil, legId: nil, value: 14)
        let ladder = PassportLogic.ladder(Passport.Milestones(achieved: [earned, odd], next: [next]))
        let journeys = ladder.first { $0.family == .journeys }!
        #expect(journeys.rungs.map(\.milestone.target) == [1, 10, 25, 50, 100, 250])
        #expect(journeys.rungs.map(\.earned) == [false, true, false, false, false, false])
        // A locked level shows the family's current value; the earned one keeps its own medal (date and trip).
        #expect(journeys.rungs[2].milestone.value == 14)
        #expect(journeys.rungs[1].milestone.legId == "L")
        #expect(journeys.earned == 1)
        // The server counted six kinds of train: the sixth is a rung too, never dropped.
        let kinds = ladder.first { $0.family == .kindsOfTrain }!
        #expect(kinds.rungs.map(\.milestone.target) == [5, 6])
        #expect(ladder.count == MilestoneFamily.knownCases.count)
    }

    @Test func theSameStretchRiddenTwiceIsOneLineWithWeightTwo() {
        let there = Polyline.encode([LatLon(59.33, 18.06), LatLon(58.6, 16.2), LatLon(57.71, 11.97)])
        let back = Polyline.encode([LatLon(57.71, 11.97), LatLon(58.6, 16.2), LatLon(59.33, 18.06)])
        let other = Polyline.encode([LatLon(59.33, 18.06), LatLon(59.86, 17.64)])
        let routes = [
            Passport.MapRoute(legId: "1", operatorId: "sj", geometry: there, stops: []),
            Passport.MapRoute(legId: "2", operatorId: "mtrx", geometry: back, stops: []),
            Passport.MapRoute(legId: "3", operatorId: "sj", geometry: other, stops: []),
            Passport.MapRoute(legId: "4", operatorId: nil, geometry: nil, stops: [[59.33, 18.06], [55.6, 13.0]]),
            Passport.MapRoute(legId: "5", operatorId: nil, geometry: nil, stops: [[55.6, 13.0], [59.33, 18.06]]),
        ]
        let weights = PassportLogic.routeWeights(routes)
        #expect(weights.map(\.count) == [2, 1, 2])
        #expect(weights[0].geometry == there)
        #expect(weights[2].geometry == nil && weights[2].stops.count == 2)
    }
}
