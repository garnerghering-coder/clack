//
//  TapTests.swift
//  ClackUITests
//
//  The taps that broke in build 20 (a zero-distance drag over the whole app and interactive glass took them): the
//  Upcoming/Past switch, a trip and its back arrow and menu, Settings and back, and the tabs. Needs the Mac's server
//  running (`npm run dev`) with the sample phone's trips (debug builds talk to it).
//

import XCTest

final class TapTests: XCTestCase {
    private let samplePhone = "b7049438-853e-4933-811a-c8fb9f364f4a"

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-userId", samplePhone, "-tab", "trips"]
        app.launch()
        // The splash lies over everything for about a second, and taps under it go nowhere: wait until it's gone.
        let splash = app.descendants(matching: .any).matching(identifier: "splash").firstMatch
        _ = splash.waitForExistence(timeout: 3)
        XCTAssertTrue(splash.waitForNonExistence(timeout: 20), "the splash never went")
        sleep(1)
        return app
    }

    /// Waits up to 5 s for an element to match (a selection animates before it reads as selected).
    @MainActor
    private func waitFor(_ element: XCUIElement, _ format: String) -> Bool {
        XCTWaiter().wait(for: [expectation(for: NSPredicate(format: format), evaluatedWith: element)], timeout: 5) == .completed
    }

    @MainActor
    func testUpcomingAndPastSwitch() throws {
        let app = launch()
        let past = app.buttons["Past"]
        XCTAssertTrue(past.waitForExistence(timeout: 15))
        past.tap()
        XCTAssertTrue(waitFor(past, "isSelected == true"), "Past didn't take the tap")
        let upcoming = app.buttons["Upcoming"]
        upcoming.tap()
        XCTAssertTrue(waitFor(upcoming, "isSelected == true"), "Upcoming didn't take the tap")
    }

    @MainActor
    func testOpenATripAndGoBack() throws {
        let app = launch()
        let past = app.buttons["Past"]
        XCTAssertTrue(past.waitForExistence(timeout: 15))
        past.tap()
        // A past trip of the sample phone, by its train number.
        let row = app.staticTexts["SJ 439"].firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 10))
        row.tap()
        let back = app.buttons["trip.back"]
        XCTAssertTrue(back.waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["trip.more"].exists)
        back.tap()
        XCTAssertTrue(app.buttons["Past"].waitForExistence(timeout: 5), "Back didn't go back")
    }

    @MainActor
    func testTabsSwitch() throws {
        let app = launch()
        let passport = app.tabBars.buttons["Passport"]
        XCTAssertTrue(passport.waitForExistence(timeout: 15))
        passport.tap()
        let ok = waitFor(passport, "isSelected == true")
        if !ok {
            print("HIERARCHY-T\n\(app.debugDescription)")
            let shot = XCTAttachment(screenshot: app.screenshot())
            shot.lifetime = .keepAlways
            add(shot)
        }
        XCTAssertTrue(ok, "The Passport tab didn't take the tap")
        let trips = app.tabBars.buttons["Trips"]
        trips.tap()
        XCTAssertTrue(waitFor(trips, "isSelected == true"), "The Trips tab didn't take the tap")
    }

    /// Taps the switch back and forth and counts the taps that didn't land (should be none).
    @MainActor
    func testManyTaps() throws {
        let app = launch()
        let past = app.buttons["Past"], upcoming = app.buttons["Upcoming"]
        XCTAssertTrue(past.waitForExistence(timeout: 15))
        var missed: [Int] = []
        for i in 0..<12 {
            let target = i % 2 == 0 ? past : upcoming
            target.tap()
            if !waitFor(target, "isSelected == true") { missed.append(i) }
        }
        let tabs = ["Passport", "Explore", "Trips", "Passport", "Trips"]
        for (i, name) in tabs.enumerated() {
            let b = app.tabBars.buttons[name]
            b.tap()
            if !waitFor(b, "isSelected == true") { missed.append(100 + i) }
        }
        XCTAssertEqual(missed, [], "taps that didn't land")
    }
}
