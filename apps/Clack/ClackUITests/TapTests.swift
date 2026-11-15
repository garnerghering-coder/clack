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

    /// A past trip of the sample phone, by its train number: one scroll since polish pass 1 (no Upcoming/Past), and
    /// each row reads as one sentence starting with the train.
    @MainActor
    private func scrollToRow(_ app: XCUIApplication, startingWith text: String) -> XCUIElement {
        let row = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", text)).firstMatch
        var tries = 0
        // Single trips have the journey's taller row since build 79: more swipes to reach the same trip.
        while !(row.exists && row.isHittable) && tries < 24 {
            app.swipeUp()
            tries += 1
        }
        return row
    }

    @MainActor
    func testHistoryIsInTheSameScroll() throws {
        let app = launch()
        XCTAssertTrue(app.staticTexts["Trips"].waitForExistence(timeout: 15))
        let row = scrollToRow(app, startingWith: "SJ 439")
        XCTAssertTrue(row.exists && row.isHittable, "a past trip wasn't reached by scrolling")
    }

    @MainActor
    func testOpenATripAndGoBack() throws {
        let app = launch()
        XCTAssertTrue(app.staticTexts["Trips"].waitForExistence(timeout: 15))
        let row = scrollToRow(app, startingWith: "SJ 439")
        XCTAssertTrue(row.exists)
        row.tap()
        // The system's back button since build 59 (the trip page has the navigation bar again).
        let back = app.navigationBars.buttons.element(boundBy: 0)
        XCTAssertTrue(back.waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["trip.more"].exists)
        back.tap()
        XCTAssertTrue(app.staticTexts["Trips"].waitForExistence(timeout: 5), "Back didn't go back")
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

    /// Taps the tabs back and forth and counts the taps that didn't land (should be none).
    @MainActor
    func testManyTaps() throws {
        let app = launch()
        XCTAssertTrue(app.tabBars.buttons["Passport"].waitForExistence(timeout: 15))
        var missed: [Int] = []
        let tabs = ["Passport", "Explore", "Trips", "Passport", "Trips"]
        for (i, name) in tabs.enumerated() {
            let b = app.tabBars.buttons[name]
            b.tap()
            if !waitFor(b, "isSelected == true") { missed.append(100 + i) }
        }
        XCTAssertEqual(missed, [], "taps that didn't land")
    }
}
