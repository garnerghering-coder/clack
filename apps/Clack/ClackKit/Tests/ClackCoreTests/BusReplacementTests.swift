//
//  BusReplacementTests.swift
//  ClackTests
//

import Testing
@testable import ClackCore

/// "Replaced by bus" only where the source says a bus runs (Jönköping C, 2026-11-07: Västtågen cancelled, "Buss ersätter").
struct BusReplacementTests {
    @Test func trafikverketsCodeOrItsWordsMeanABus() {
        #expect(LegStop.Cause(src: "trv", code: "ANA007", text: "Buss ersätter").isBusReplacement)
        #expect(LegStop.Cause(src: "trv", text: "Buss ersätter").isBusReplacement)
        #expect(LegStop.Cause(src: "entur", text: "Buss for tog mellom Oslo S og Drammen").isBusReplacement)
    }

    @Test func otherNotesAreNotABus() {
        #expect(!LegStop.Cause(src: "trv", code: "ANA003", text: "Banarbete").isBusReplacement)
        #expect(!LegStop.Cause(src: "trv", text: "Inställt").isBusReplacement)
        #expect(!LegStop.Cause(src: "trv").isBusReplacement)
    }
}
