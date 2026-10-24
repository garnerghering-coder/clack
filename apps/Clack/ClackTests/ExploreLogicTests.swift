//
//  ExploreLogicTests.swift
//  ClackTests
//

import Foundation
import Testing
@testable import Clack
@testable import ClackCore

struct ExploreLogicTests {
    private func train(_ id: String = "1|2026-10-23", number: String = "1", product: String? = "regional", op: String? = "sj", delay: Int? = nil, mine: Bool = false, estimated: Bool = false, at: Double = 0) -> LiveTrain {
        LiveTrain(
            id: id, number: number, date: "2026-10-23", lat: 59, lon: 18, bearing: nil, speedKmh: nil, at: Instant(ms: at), estimated: estimated,
            operatorId: op, productName: nil, product: product, trainType: nil, origin: nil, destination: nil, next: nil, nextEta: nil,
            delayMin: delay, mine: mine, tripKey: nil, crossBorder: nil
        )
    }

    @Test func filtersByProductOperatorDelayMineAndFollowed() {
        var f = ExploreLogic.Filters()
        #expect(ExploreLogic.visible(train(), f, followed: []))
        f.products = ["night"]
        #expect(!ExploreLogic.visible(train(), f, followed: []))
        f = .init(); f.operators = ["mtr"]
        #expect(!ExploreLogic.visible(train(), f, followed: []))
        f = .init(); f.onlyDelayed = true
        #expect(!ExploreLogic.visible(train(delay: 5), f, followed: []))
        #expect(ExploreLogic.visible(train(delay: 6), f, followed: []))
        f = .init(); f.onlyMine = true
        #expect(ExploreLogic.visible(train(mine: true), f, followed: []))
        #expect(!ExploreLogic.visible(train(), f, followed: []))
        f = .init(); f.onlyFollowed = true
        #expect(ExploreLogic.visible(train(number: "1"), f, followed: ["1|2026-10-23"]))
        #expect(!ExploreLogic.visible(train(number: "2"), f, followed: ["1|2026-10-23"]))
    }

    @Test func theFilterBadgeCountsEachChoice() {
        var f = ExploreLogic.Filters()
        f.products = ["a", "b"]; f.operators = ["c"]; f.onlyDelayed = true
        #expect(f.count == 4)
    }

    @Test func aMovedTrainKeepsEverythingButItsPosition() {
        let old = train(op: "sj")
        let moved = MovedTrain.test(id: old.id, lat: 60, lon: 19, bearing: 90, speed: 80, at: 5, estimated: true)
        let new = ExploreLogic.applying(moved, to: old)
        #expect(new.lat == 60 && new.lon == 19 && new.bearing == 90 && new.speedKmh == 80 && new.estimated && new.at.ms == 5)
        #expect(new.operatorId == "sj" && new.number == old.number)
    }

    @Test func decodesTheMovedTupleAndTheDelta() throws {
        let json = #"{"changed":[],"moved":[["1|2026-10-23",59.1,18.2,null,null,1792766570000,true]],"removed":["x"],"total":5,"upstreamAt":1}"#
        let delta = try JSONDecoder().decode(LiveDelta.self, from: Data(json.utf8))
        #expect(delta.moved?.first?.lat == 59.1)
        #expect(delta.moved?.first?.bearing == nil)
        #expect(delta.moved?.first?.estimated == true)
        #expect(delta.removed == ["x"])
    }

    @Test func nearestOnLineProjectsOntoTheSegmentAndNeverStartsBeforeFrom() {
        let line = [LatLon(0, 0), LatLon(0, 1), LatLon(0, 2)]
        let hit = ExploreLogic.nearestOnLine(line, LatLon(0.1, 1.5))
        #expect(hit.index == 1)
        #expect(abs(hit.point.lon - 1.5) < 1e-9 && abs(hit.point.lat) < 1e-9)
        let later = ExploreLogic.nearestOnLine(line, LatLon(0, 0.2), from: 1)
        #expect(later.index == 1)
    }

    @Test func splitsTheRouteAtTheTrainAndBacksUpThreeSegments() {
        let line = (0...10).map { LatLon(0, Double($0)) }
        let s = ExploreLogic.split(line, at: LatLon(0, 6.5), from: 0)
        #expect(s.done.last == LatLon(0, 6.5) && s.ahead.first == LatLon(0, 6.5))
        #expect(s.done.count == 8 && s.ahead.count == 5)
        #expect(s.next == 3)
    }

    @Test func glidesWithEaseOutOverOneAndAHalfSeconds() {
        let a = LatLon(0, 0), b = LatLon(10, 10)
        #expect(ExploreLogic.glide(from: a, to: b, startedAt: 0, now: 0).position == a)
        let half = ExploreLogic.glide(from: a, to: b, startedAt: 0, now: 750)
        #expect(abs(half.position.lat - 8.75) < 1e-9 && !half.done)
        let end = ExploreLogic.glide(from: a, to: b, startedAt: 0, now: 2000)
        #expect(end.position == b && end.done)
    }

    @Test func statusChipFirstMatchWins() {
        func status(loaded: Bool = true, down: Bool = false, last: Double = 0, mode: String? = "stream", upstream: Double = 100_000, shown: Int = 3, zoom: Double = 5, filtered: Bool = false, now: Double = 100_000) -> ExploreLogic.Status {
            ExploreLogic.status(loaded: loaded, streamDown: down, lastMessageAt: last, mode: mode, upstreamAt: upstream, shown: shown, total: 40, zoom: zoom, filtered: filtered, now: now)
        }
        #expect(status(loaded: false) == .loading)
        #expect(status(down: true, last: 0, now: 100_000) == .unavailable)
        #expect(status(mode: "stopped") == .unavailable)
        #expect(status(upstream: 10_000) == .delayed(upstreamAt: 10_000))
        #expect(status(shown: 0, zoom: 7, filtered: true) == .none(filtered: true))
        #expect(status(shown: 0, zoom: 5) == .running(total: 40, simulated: false))
        #expect(status(mode: "simulate") == .running(total: 40, simulated: true))
        // Streaming down for a moment, but a message came recently: not "unavailable" yet.
        #expect(status(down: true, last: 95_000) == .running(total: 40, simulated: false))
    }

    @Test func positionIsEstimatedOldOrGps() {
        #expect(ExploreLogic.position(of: train(estimated: true), now: 0) == .estimated)
        #expect(ExploreLogic.position(of: train(at: 0), now: 119_000) == .gps)
        #expect(ExploreLogic.position(of: train(at: 0), now: 180_000) == .old(minutes: 3))
    }

    @Test func searchFindsRunningTrainsByNumberPrefix() {
        let trains = (100...110).map { train("\($0)|d", number: String($0)) } + [train("5|d", number: "5")]
        #expect(ExploreLogic.trainHits(trains, query: "10").count == 6)
        #expect(ExploreLogic.trainHits(trains, query: "5").map(\.number) == ["5"])
        #expect(ExploreLogic.trainHits(trains, query: "").isEmpty)
        #expect(ExploreLogic.trainHits(trains, query: "SJ 10").count == 6)
        #expect(ExploreLogic.trainHits(trains, query: "abc").isEmpty)
        #expect(ExploreLogic.searchesStations("Gö"))
        #expect(!ExploreLogic.searchesStations("336"))
        #expect(!ExploreLogic.searchesStations("g"))
    }

    @Test func sheetSizesFollowTheRoomAndTheContent() {
        let t = ExploreLogic.sheetTargets(room: 700, content: 900, head: 60, foot: 74)
        #expect(t.full == 676)
        #expect(t.mid == 518)
        #expect(t.small == 254)
        let short = ExploreLogic.sheetTargets(room: 700, content: 300, head: 60, foot: 74)
        #expect(short.mid == 300 && short.small == 254)
    }

    @Test func aDragSettlesOnTheNearestSizeAndAFlickGoesOneFurther() {
        let t = ExploreLogic.SheetTargets(small: 250, mid: 500, full: 700)
        #expect(ExploreLogic.settle(height: 480, velocity: 0, from: .mid, targets: t) == .mid)
        #expect(ExploreLogic.settle(height: 640, velocity: 0, from: .mid, targets: t) == .full)
        #expect(ExploreLogic.settle(height: 505, velocity: -0.8, from: .mid, targets: t) == .full)
        #expect(ExploreLogic.settle(height: 495, velocity: 0.8, from: .mid, targets: t) == .small)
        #expect(ExploreLogic.settle(height: 250, velocity: -0.8, from: .small, targets: t) == .mid)
    }

    @Test func stopTimesUseArrivalForTheLastStopAndActualBeforeEstimated() {
        let mid = LiveTrainStop(seq: 2, stationId: "a", name: "A", arr: 0, dep: 60_000, actualArr: nil, actualDep: nil, estimatedArr: nil, estimatedDep: 5 * 60_000 + 60_000, platform: nil, canceled: false, passed: false)
        let t = ExploreLogic.stopTimes(mid, isLast: false)
        #expect(t.planned == 60_000 && t.real == 360_000 && t.lateMinutes == 5)
        let last = LiveTrainStop(seq: 3, stationId: "b", name: "B", arr: 600_000, dep: nil, actualArr: 540_000, actualDep: nil, estimatedArr: nil, estimatedDep: nil, platform: nil, canceled: false, passed: true)
        #expect(ExploreLogic.stopTimes(last, isLast: true).lateMinutes == -1)
    }

    @Test func nextStopIsTheFirstNotPassedNorCancelled() {
        func stop(_ seq: Int, passed: Bool = false, canceled: Bool = false) -> LiveTrainStop {
            LiveTrainStop(seq: seq, stationId: "s", name: "S", arr: nil, dep: nil, actualArr: nil, actualDep: nil, estimatedArr: nil, estimatedDep: nil, platform: nil, canceled: canceled, passed: passed)
        }
        let stops = [stop(1, passed: true), stop(2, canceled: true), stop(3), stop(4)]
        #expect(ExploreLogic.nextStopIndex(stops) == 2)
        #expect(ExploreLogic.catchableFrom(stops)?.seq == 3)
        #expect(ExploreLogic.catchableFrom([stop(1, passed: true), stop(2)]) == nil)
    }
}

extension MovedTrain {
    /// The tuple as the server sends it.
    static func test(id: String, lat: Double, lon: Double, bearing: Double?, speed: Double?, at: Double, estimated: Bool) -> MovedTrain {
        func text(_ value: Double?) -> String { value == nil ? "null" : String(value!) }
        let fields: [String] = ["\"\(id)\"", String(lat), String(lon), text(bearing), text(speed), String(at), String(estimated)]
        let json = "[" + fields.joined(separator: ",") + "]"
        return try! JSONDecoder().decode(MovedTrain.self, from: Data(json.utf8))
    }
}
