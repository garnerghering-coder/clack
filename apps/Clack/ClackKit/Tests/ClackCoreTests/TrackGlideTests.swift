//
//  TrackGlideTests.swift
//  ClackTests
//

import Foundation
import Testing
@testable import ClackCore

struct TrackGlideTests {
    /// 1 km north, then 1 km east (a right-angle bend) near Stockholm.
    private var bend: ExploreLogic.TrackPath {
        let a = LatLon(59.0, 18.0)
        let b = LatLon(59.0 + 1000 / 111_320, 18.0)
        let c = LatLon(b.lat, 18.0 + 1000 / (111_320 * cos(b.lat * .pi / 180)))
        return ExploreLogic.TrackPath(points: [a, b, c])
    }

    @Test func lengthAndBearings() {
        let t = bend
        #expect(abs(t.length - 2000) < 5)
        #expect(abs(t.at(500).bearing - 0) < 1)
        #expect(abs(t.at(1500).bearing - 90) < 1)
        #expect(t.at(5000).position == t.points.last)
    }

    @Test func projectsOntoTheTrack() {
        let t = bend
        let p = t.at(1200).position
        let r = t.project(LatLon(p.lat + 0.00002, p.lon))
        #expect(abs(r.along - 1200) < 5)
        #expect(r.offsetM < 5)
    }

    @Test func followsTheBendAndNeverPassesTheEnd() {
        let t = bend
        let g = ExploreLogic.Glide(track: t, fromM: 900, toM: 1000, speed: 30, start: 0)
        #expect(g.step(now: 100).done == false)
        // After 1.5 s it is at the update's point plus 1.5 s at 30 m/s, on the east leg, heading east.
        let mid = g.step(now: 1500)
        #expect(ExploreLogic.metres(mid.position, t.at(1045).position) < 2)
        #expect(abs((mid.bearing ?? 0) - 90) < 1)
        let end = g.step(now: 10_000)
        #expect(end.done)
        #expect(ExploreLogic.metres(end.position, t.at(1120).position) < 2)
        // Right at the end of the track it stops there.
        let last = ExploreLogic.Glide(track: t, fromM: 1950, toM: 1990, speed: 50, start: 0).step(now: 3000)
        #expect(ExploreLogic.metres(last.position, t.points.last!) < 1)
        #expect(last.done)
    }

    @Test func standingTrainsAndOffTrackFixesGlideStraight() {
        let t = bend
        let a = t.at(100).position, b = t.at(130).position
        #expect(ExploreLogic.makeGlide(track: t, from: a, to: b, standing: true, speedKmh: 40, start: 0).track == nil)
        #expect(ExploreLogic.makeGlide(track: nil, from: a, to: b, standing: false, speedKmh: 40, start: 0).track == nil)
        #expect(ExploreLogic.makeGlide(track: t, from: a, to: LatLon(b.lat, b.lon + 0.01), standing: false, speedKmh: 40, start: 0).track == nil)
        #expect(ExploreLogic.makeGlide(track: t, from: a, to: b, standing: false, speedKmh: 40, start: 0).track != nil)
        // No speed: the glide ends where the update put it and does not creep.
        let still = ExploreLogic.Glide(track: t, fromM: 100, toM: 100, speed: 0, start: 0)
        #expect(ExploreLogic.metres(still.step(now: 3000).position, a) < 0.5)
    }

    @Test func movedTupleCarriesStateAndProgress() throws {
        let json = #"["a|d",59.1,18.1,90,60,1000,false,"standing",0.5]"#
        let m = try JSONDecoder().decode(MovedTrain.self, from: Data(json.utf8))
        #expect(m.state == "standing" && m.progress == 0.5)
        let old = try JSONDecoder().decode(MovedTrain.self, from: Data(#"["a|d",59.1,18.1,null,null,1000,false]"#.utf8))
        #expect(old.state == nil && old.progress == nil)
    }
}
