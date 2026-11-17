//
//  TrainStripLayoutTests.swift
//  ClackTests
//

import Testing
@testable import ClackCore

/// The trains on a search result: one scale, the first leading, the rest behind (owner, 2026-11-17).
struct TrainStripLayoutTests {
    private let row = 354.0

    /// What shows of the row: each slot less the part under the train before it.
    private func shown(_ slots: [TrainStripLayout.Slot]) -> Double { slots.reduce(0) { $0 + $1.width - $1.overlap } }

    @Test func oneTrainIsShownWhole() {
        let s = TrainStripLayout.slots(naturals: [120], width: row)
        #expect(s == [.init(width: 120, cut: false, overlap: 0)])
    }

    @Test func twoTrainsFitHalfEachAndTheSecondSlidesUnder() {
        let s = TrainStripLayout.slots(naturals: [99, 120], width: row)
        #expect(s[0] == .init(width: 99, cut: false, overlap: 0))
        #expect(s[1].cut == false && s[1].width == 120 && s[1].overlap == 12)
    }

    @Test func aShortLocomotiveIsNotCutAndALongTrainIs() {
        let s = TrainStripLayout.slots(naturals: [242, 80, 242], width: row)
        #expect(s[0].cut && s[0].width == row * 0.38)
        #expect(!s[1].cut && s[1].width == 80)
        #expect(s[2].cut)
    }

    @Test func theFirstLeadsFromFourTrains() {
        let caps = TrainStripLayout.caps(count: 4, width: row)
        #expect(caps[0] > caps[1] && caps[1] == caps[2] && caps[2] == caps[3])
        let five = TrainStripLayout.caps(count: 5, width: row)
        #expect(five[1] < caps[1])
    }

    @Test func laterTrainsNeverShowLessThanANose() {
        let caps = TrainStripLayout.caps(count: 12, width: row)
        #expect(caps.dropFirst().allSatisfy { $0 == TrainStripLayout.minShown })
    }

    @Test func whatShowsNeverRunsPastTheRow() {
        for n in 1...6 {
            let s = TrainStripLayout.slots(naturals: Array(repeating: 242, count: n), width: row)
            #expect(shown(s) <= row + 0.001, "\(n) trains")
        }
    }

    @Test func theRowIsTheTallestDrawing() {
        #expect(abs(TrainStripLayout.height - 28.6) < 0.01)
    }
}
