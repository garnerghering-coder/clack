//
//  InstantTests.swift
//  ClackTests
//

import Foundation
import Testing
@testable import Clack

struct InstantTests {
    private func decode(_ json: String) throws -> Instant {
        try JSONDecoder().decode(Instant.self, from: Data(json.utf8))
    }

    @Test func isoWithFractionalSeconds() throws {
        #expect(try decode(#""2026-10-23T08:12:00.000Z""#).ms == 1_792_743_120_000)
    }

    @Test func isoWithoutFractionalSeconds() throws {
        #expect(try decode(#""2026-10-23T08:12:00Z""#).ms == 1_792_743_120_000)
    }

    @Test func isoWithFractionKeepsTheMilliseconds() throws {
        #expect(try decode(#""2026-10-23T08:12:00.250Z""#).ms == 1_792_743_120_250)
    }

    @Test func epochMilliseconds() throws {
        #expect(try decode("1792743120000").ms == 1_792_743_120_000)
    }

    @Test func bothFormsGiveTheSameInstant() throws {
        #expect(try decode(#""2026-10-23T08:12:00.000Z""#) == decode("1792743120000"))
    }

    @Test func notATimeFails() {
        #expect(throws: DecodingError.self) { try decode(#""soon""#) }
    }

    @Test func encodesAsMilliseconds() throws {
        let data = try JSONEncoder().encode([Instant(ms: 1_792_743_120_000)])
        #expect(String(decoding: data, as: UTF8.self) == "[1792743120000]")
    }

    @Test func dateAndOrdering() throws {
        let early = Instant(ms: 1000)
        let late = Instant(ms: 2000)
        #expect(early < late)
        #expect(early.date == Date(timeIntervalSince1970: 1))
    }
}
