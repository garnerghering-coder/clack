import Foundation
import Testing
@testable import ClackCore

struct RiderLogicTests {
    // A 10 km track due north from 57.0, 14.0.
    let track = ExploreLogic.TrackPath(points: (0...10).map { LatLon(57 + Double($0) * 1000 / 111_195, 14) })

    @Test func aRiderOnTheTrackIsSnappedOntoIt() throws {
        let fix = LatLon(57 + 4000 / 111_195, 14 + 30 / (111_320 * cos(57 * Double.pi / 180)))
        let s = try #require(RiderLogic.snap(fix: fix, accuracyM: 10, speedMps: 25, track: track, feedProgress: 0.3))
        #expect(abs(s.alongM - 4000) < 20)
        #expect(abs(s.progress - 0.4) < 0.002)
        #expect(s.speedKmh == 90)
    }

    @Test func nothingIsSentWhenItDoesNotLookLikeARiderOnThisTrain() {
        let on = LatLon(57 + 4000 / 111_195, 14)
        // Imprecise, standing, off the track (200 m east), and far from where the feed has the train.
        #expect(RiderLogic.snap(fix: on, accuracyM: 120, speedMps: 25, track: track, feedProgress: nil) == nil)
        #expect(RiderLogic.snap(fix: on, accuracyM: 10, speedMps: 2, track: track, feedProgress: nil) == nil)
        let off = LatLon(on.lat, 14 + 200 / (111_320 * cos(57 * Double.pi / 180)))
        #expect(RiderLogic.snap(fix: off, accuracyM: 10, speedMps: 25, track: track, feedProgress: nil) == nil)
        let long = ExploreLogic.TrackPath(points: (0...50).map { LatLon(57 + Double($0) * 1000 / 111_195, 14) })
        #expect(RiderLogic.snap(fix: on, accuracyM: 10, speedMps: 25, track: long, feedProgress: 0.9) == nil)
    }

    @Test func theReportCarriesNoCoordinatesAndIsRounded() throws {
        let r = RiderLogic.Report(train: "dk:1|2026-10-30", prevId: "A", nextId: "B", progress: 0.123456, speedKmh: 88.7, at: 1_800_000_000_456, session: "abcdefgh-1")
        let json = try #require(String(data: JSONEncoder().encode(r), encoding: .utf8))
        #expect(!json.contains("lat") && !json.contains("lon") && !json.contains("user"))
        #expect(r.progress == 0.1235 && r.speedKmh == 89 && r.at == 1_800_000_000_000)
    }
}
