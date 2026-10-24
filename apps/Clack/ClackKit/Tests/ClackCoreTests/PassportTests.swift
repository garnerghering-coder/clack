//
//  PassportTests.swift
//  ClackTests
//

import Foundation
import Testing
@testable import ClackCore

struct PassportTests {
    @Test func decodesARealServerResponse() throws {
        let url = try #require(Bundle.module.url(forResource: "passport", withExtension: "json", subdirectory: "Fixtures"))
        let passport = try JSONDecoder().decode(Passport.self, from: Data(contentsOf: url))
        #expect(passport.totals.trains >= 0)
        #expect(passport.map.count <= passport.totals.trains)
        #expect(passport.delays.bands.onTime >= 0)
    }
}

