//
//  WidgetTimelineTests.swift
//  ClackCoreTests
//
//  When the widgets redraw and which journey each redraw shows (workstream C): the Next journey timeline, its reload, the
//  countdown's wording, and the Departures rows.
//

import Foundation
import Testing
@testable import ClackCore

private let m = 60_000.0
private let h = 60 * m
/// A whole minute, like the server's times.
private let now = 1_800_000_000_000.0

private func leg(_ id: String, journey: String? = nil, dep: Double, arr: Double) -> WidgetSnapshot.Leg {
    WidgetSnapshot.Leg(
        id: id, journeyId: journey, from: "A", to: "B", fromTz: "Europe/Stockholm", toTz: "Europe/Stockholm",
        depAt: now + dep, arrAt: now + arr, canceled: false
    )
}

private func snapshot(_ journey: [WidgetSnapshot.Leg], next: [WidgetSnapshot.Leg] = []) -> WidgetSnapshot {
    WidgetSnapshot(updatedAt: now, journey: journey, nextJourney: next)
}

/// What a redraw shows, as far as the eye can tell between two redraws: the journey, the moment and the countdown's words.
private func look(_ s: WidgetSnapshot, at t: Double) -> String {
    guard let shown = WidgetTimeline.shown(s, at: t) else { return "none" }
    let id = shown.legs.first?.id ?? ""
    switch shown.moment {
    case .before:
        let dep = shown.legs[0].depAt
        // Within 30 minutes the widget shows a running timer, which counts by itself.
        if dep - t <= WidgetTimeline.denseBeforeMs { return "\(id) soon" }
        return "\(id) " + WidgetTimeline.text(WidgetTimeline.countdown(to: dep, now: t))
    case .onTrain(let i, _): return "\(id) on \(i)"
    case .changing(let i, _): return "\(id) change \(i)"
    case .finished: return "\(id) arrived"
    }
}

struct WhichJourneyTests {
    private let hero = [leg("a", journey: "j1", dep: 10 * m, arr: 60 * m), leg("b", journey: "j1", dep: 70 * m, arr: 120 * m)]
    private let next = [leg("c", journey: "j2", dep: 4 * h, arr: 5 * h)]

    @Test func theFeaturedJourneyUntilTwoMinutesAfterItsLastArrival() {
        let s = snapshot(hero, next: next)
        #expect(WidgetTimeline.shown(s, at: now)?.legs.map(\.id) == ["a", "b"])
        #expect(WidgetTimeline.shown(s, at: now + 121 * m)?.moment == .finished)
        #expect(WidgetTimeline.shown(s, at: now + 121 * m)?.legs.first?.id == "a")
    }

    @Test func thenTheNextJourney() {
        let s = snapshot(hero, next: next)
        let after = WidgetTimeline.shown(s, at: now + 122 * m)
        #expect(after?.legs.map(\.id) == ["c"])
        #expect(after?.moment == .before(leg: 0))
    }

    @Test func withNothingNextTheEndedJourneyStaysAsArrivedForSixHours() {
        let s = snapshot(hero)
        #expect(WidgetTimeline.shown(s, at: now + 3 * h)?.moment == .finished)
        #expect(WidgetTimeline.shown(s, at: now + 3 * h)?.leg?.id == "b")
        #expect(WidgetTimeline.shown(s, at: now + 2 * h + 6 * h) == nil)
    }

    @Test func nothingToShowWithNoJourney() {
        #expect(WidgetTimeline.shown(WidgetSnapshot(), at: now) == nil)
    }
}

struct CountdownTests {
    @Test func toTheMinuteWithinHalfAnHour() {
        #expect(WidgetTimeline.countdown(to: now + 25 * m, now: now) == .minutes(25))
        #expect(WidgetTimeline.countdown(to: now + 90_000, now: now) == .minutes(2))
    }

    @Test func byTheQuarterHourWithinSixHoursRoundedDown() {
        #expect(WidgetTimeline.countdown(to: now + 134 * m, now: now) == .minutes(120))
        #expect(WidgetTimeline.countdown(to: now + 135 * m, now: now) == .minutes(135))
        #expect(WidgetTimeline.countdown(to: now + 6 * h, now: now) == .minutes(360))
    }

    @Test func byTheHourWithinADayThenByTheDay() {
        #expect(WidgetTimeline.countdown(to: now + 6 * h + m, now: now) == .hours(6))
        #expect(WidgetTimeline.countdown(to: now + 23 * h + 59 * m, now: now) == .hours(23))
        #expect(WidgetTimeline.countdown(to: now + 50 * h, now: now) == .days(2))
    }

    @Test func words() {
        #expect(WidgetTimeline.text(.minutes(45)) == "45 min")
        #expect(WidgetTimeline.text(.minutes(135)) == "2h 15m")
        #expect(WidgetTimeline.text(.minutes(120)) == "2h")
        #expect(WidgetTimeline.text(.hours(7)) == "7h")
        #expect(WidgetTimeline.text(.days(2)) == "2d")
    }
}

struct JourneyTimelineTests {
    @Test func startsNowAndStaysWithinThreeHours() {
        let s = snapshot([leg("a", dep: 20 * m, arr: 50 * m)])
        let dates = WidgetTimeline.journeyEntries(s, now: now + 7_000)
        #expect(dates.first == now + 7_000)
        #expect(dates.last! <= now + 7_000 + 3 * h)
        #expect(dates == dates.sorted())
        #expect(Set(dates).count == dates.count)
    }

    @Test func everyMinuteFromHalfAnHourBeforeUntilTwoMinutesAfterArrival() {
        let s = snapshot([leg("a", dep: 20 * m, arr: 50 * m)])
        let dates = Set(WidgetTimeline.journeyEntries(s, now: now))
        for minute in 1...52 { #expect(dates.contains(now + Double(minute) * m), "minute \(minute)") }
    }

    @Test func farAheadOnlyWhenTheWordingChanges() {
        // 20 hours away: "19h" ... the wording changes on the hour, so three hours hold three or four entries.
        let s = snapshot([leg("a", dep: 20 * h, arr: 22 * h)])
        let dates = WidgetTimeline.journeyEntries(s, now: now + 30_000)
        #expect(dates.count <= 5)
        #expect(dates.count >= 3)
    }

    /// Between two redraws nothing on the widget would change: for every minute (and between them) the last entry before
    /// it shows the same thing.
    @Test(arguments: [
        snapshot([leg("a", journey: "j", dep: 10 * m, arr: 60 * m), leg("b", journey: "j", dep: 75 * m, arr: 150 * m)], next: [leg("c", dep: 160 * m, arr: 4 * h)]),
        snapshot([leg("a", dep: 5 * h + 7 * m, arr: 6 * h)]),
        snapshot([leg("a", dep: 26 * h + 3 * m, arr: 30 * h)]),
        snapshot([leg("a", dep: -2 * h, arr: -1 * h)]),
    ])
    func eachEntryHoldsUntilTheNext(s: WidgetSnapshot) {
        for start in [now, now + 17_000, now + 41 * m + 5_000] {
            let dates = WidgetTimeline.journeyEntries(s, now: start)
            var t = start
            while t < start + WidgetTimeline.horizonMs {
                let entry = dates.last { $0 <= t }!
                #expect(look(s, at: entry) == look(s, at: t), "at +\((t - now) / m) min from the entry at +\((entry - now) / m)")
                t += 20_000
            }
        }
    }

    @Test func entriesAfterTheEndAlreadyShowTheNextJourney() {
        let s = snapshot([leg("a", dep: 10 * m, arr: 60 * m)], next: [leg("c", dep: 5 * h, arr: 6 * h)])
        let dates = WidgetTimeline.journeyEntries(s, now: now)
        let after = dates.filter { $0 >= now + 62 * m }
        #expect(!after.isEmpty)
        for t in after { #expect(WidgetTimeline.shown(s, at: t)?.legs.first?.id == "c") }
    }

    @Test func entriesForAnEmptySnapshotAreJustNow() {
        #expect(WidgetTimeline.journeyEntries(WidgetSnapshot(), now: now) == [now])
    }
}

struct JourneyReloadTests {
    @Test func atTheLatestInHalfAnHour() {
        #expect(WidgetTimeline.journeyReload(snapshot([leg("a", dep: 20 * h, arr: 22 * h)]), now: now) == now + 30 * m)
        #expect(WidgetTimeline.journeyReload(WidgetSnapshot(), now: now) == now + 30 * m)
    }

    @Test func soonerAtTheNextChangeOfState() {
        // The last half hour before leaving starts in 10 minutes.
        #expect(WidgetTimeline.journeyReload(snapshot([leg("a", dep: 40 * m, arr: 2 * h)]), now: now) == now + 10 * m)
        // On the train: at the arrival.
        #expect(WidgetTimeline.journeyReload(snapshot([leg("a", dep: -10 * m, arr: 12 * m)]), now: now) == now + 12 * m)
    }

    @Test func neverSoonerThanAMinute() {
        #expect(WidgetTimeline.journeyReload(snapshot([leg("a", dep: 10_000, arr: 2 * h)]), now: now) == now + m)
    }
}

struct RelevanceTests {
    @Test func highestWhileATripRunsOrIsAboutTo() {
        #expect(WidgetTimeline.relevance(snapshot([leg("a", dep: -10 * m, arr: 30 * m)]), at: now) == 1)
        #expect(WidgetTimeline.relevance(snapshot([leg("a", dep: 20 * m, arr: 60 * m)]), at: now) == 1)
        #expect(WidgetTimeline.relevance(snapshot([leg("a", dep: 2 * h, arr: 3 * h)]), at: now) == 0.5)
        #expect(WidgetTimeline.relevance(snapshot([leg("a", dep: 20 * h, arr: 22 * h)]), at: now) == 0.1)
        #expect(WidgetTimeline.relevance(WidgetSnapshot(), at: now) == 0)
    }
}

struct DeparturesTimelineTests {
    private func row(_ id: String, _ at: Double, expected: Double? = nil) -> WidgetSnapshot.Departure {
        .init(id: id, time: now + at, expected: expected.map { now + $0 }, to: "X", train: id, canceled: false)
    }

    @Test func aRedrawEveryMinuteForHalfAnHour() {
        let dates = WidgetTimeline.departureEntries(now: now + 5_000)
        #expect(dates.count == 31)
        #expect(dates.first == now + 5_000)
        #expect(dates[1] == now + m)
        #expect(dates.last == now + 30 * m)
    }

    @Test func departedTrainsDropOffThroughTheMinuteTheyLeave() {
        let rows = [row("late", 2 * m, expected: 9 * m), row("one", 3 * m), row("two", 5 * m)]
        #expect(WidgetTimeline.departures(rows, at: now + 3 * m + 30_000, limit: 8).map(\.id) == ["late", "one", "two"])
        #expect(WidgetTimeline.departures(rows, at: now + 4 * m, limit: 8).map(\.id) == ["late", "two"])
        #expect(WidgetTimeline.departures(rows, at: now + 10 * m, limit: 8).isEmpty)
        #expect(WidgetTimeline.departures(rows, at: now, limit: 2).map(\.id) == ["late", "one"])
    }
}

struct StaleTests {
    @Test func saysWhenItWasUpdatedAfterHalfAnHour() {
        #expect(!WidgetTimeline.isStale(now, now: now + 30 * m))
        #expect(WidgetTimeline.isStale(now, now: now + 31 * m))
        #expect(!WidgetTimeline.isStale(0, now: now))
    }
}
