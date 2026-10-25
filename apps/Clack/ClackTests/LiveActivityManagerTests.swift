//
//  LiveActivityManagerTests.swift
//  ClackTests
//

import Foundation
import Testing
@testable import Clack

/// The app keeps a trip card moving itself, and steps back only while the server's pushes are arriving.
@MainActor
struct LiveActivityManagerTests {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    @Test func aCardWithoutPushIsAlwaysTheApps() {
        #expect(LiveActivityManager.appMoves(hasPush: false, serverAt: nil, now: now))
        #expect(LiveActivityManager.appMoves(hasPush: false, serverAt: now, now: now))
    }

    @Test func aCardWithPushThatTheServerNeverMovedIsTheAppsToo() {
        // The freeze: a card with a push address waited for a server that never sent anything.
        #expect(LiveActivityManager.appMoves(hasPush: true, serverAt: nil, now: now))
    }

    @Test func theServersRecentPushIsLeftAloneForTwoMinutes() {
        #expect(!LiveActivityManager.appMoves(hasPush: true, serverAt: now.addingTimeInterval(-60), now: now))
        #expect(LiveActivityManager.appMoves(hasPush: true, serverAt: now.addingTimeInterval(-180), now: now))
    }
}
