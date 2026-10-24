//
//  TicketPendingTests.swift
//  ClackTests
//

import Foundation
import Testing
@testable import ClackCore

struct TicketPendingTests {
    private func defaults() throws -> UserDefaults {
        let suite = "clack.tests.tickets.\(UUID().uuidString)"
        return try #require(UserDefaults(suiteName: suite))
    }

    private func pending(at: Double) -> TicketPending {
        TicketPending(
            trip: TicketTrip(
                operatorId: "sj", trainNumber: "421",
                from: .init(name: "Stockholm C", time: 1_000, tz: "Europe/Stockholm", seq: 1),
                to: .init(name: "Göteborg C", time: 2_000, tz: "Europe/Stockholm", seq: 5), tripKey: "k", serviceDate: "2026-10-23"
            ),
            at: at, site: "sj.se"
        )
    }

    @Test func aHandOffIsKeptForThreeHours() throws {
        let store = try defaults()
        TicketPendingStore.write(pending(at: 1_000_000), store)
        #expect(TicketPendingStore.read(now: 1_000_000 + 3 * 3_600_000 - 1, store)?.site == "sj.se")
        #expect(TicketPendingStore.read(now: 1_000_000 + 3 * 3_600_000, store) == nil)
    }

    @Test func itIsOnlyOfferedAfterAFewSeconds() throws {
        let store = try defaults()
        TicketPendingStore.write(pending(at: 1_000_000), store)
        #expect(TicketPendingStore.offer(now: 1_000_000 + 4_000, store) == nil)
        #expect(TicketPendingStore.offer(now: 1_000_000 + 5_001, store)?.trip.trainNumber == "421")
    }

    @Test func clearingRemovesIt() throws {
        let store = try defaults()
        TicketPendingStore.write(pending(at: 0), store)
        TicketPendingStore.write(nil, store)
        #expect(TicketPendingStore.read(now: 1, store) == nil)
    }

    @Test func theSiteIsTheHostWithoutWww() {
        #expect(TicketPendingStore.host(of: "https://www.sj.se/sv/start") == "sj.se")
        #expect(TicketPendingStore.host(of: "https://vrresa.se") == "vrresa.se")
    }
}
