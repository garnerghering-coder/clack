//
//  OmioLinkTests.swift
//  ClackTests
//

import Foundation
import Testing
@testable import ClackCore

struct OmioLinkTests {
    @Test func theButtonOpensOmiosHomePageThroughOurAffiliateLink() {
        #expect(Config.omioURL.absoluteString == "https://omio.sjv.io/DWG092")
        #expect(Config.omioURL.scheme == "https")
    }
}
